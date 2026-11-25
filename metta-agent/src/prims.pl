:- module(prims, [
    env_get/2,
    llm_chat/4,
    shell_run/3,
    file_read/4,
    file_write/3,
    ask_user/2,
    say/2,
    parse_reply/2,
    split_cmd/2,
    path_outside_workspace/2,
    redirect_overwrites_existing/2,
    str_truncate_middle/4,
    str_concat_list/2,
    trace_log/2,
    mock_set_replies/2
]).

:- use_module(library(process)).
:- use_module(library(readutil)).
:- use_module(library(http/json)).
:- use_module(library(filesex)).
:- use_module(library(pcre)).

:- dynamic mock_queue/1.

%% env_get(+Key, -Value)
env_get(Key, Val) :-
    once((getenv(Key, Raw) -> atom_string(Raw, Val) ; Val = "")), !.

%% say(+Text, -Ack)
say(Text, "ok") :-
    once((format('~w~n', [Text]), flush_output)), !.

%% ask_user(+Prompt, -Answer)
ask_user(Prompt, Answer) :-
    once((
        format('~w ', [Prompt]),
        flush_output,
        read_line_to_string(user_input, Line),
        (Line == end_of_file -> Answer = "" ; Answer = Line)
    )), !.

%% mock_set_replies(+RepliesList)
mock_set_replies(Replies, "ok") :-
    retractall(mock_queue(_)),
    assertz(mock_queue(Replies)), !.

%% llm_chat(+SystemPrompt, +UserPrompt, +Model, -Reply)
llm_chat(SysPrompt, UserPrompt, Model, Reply) :-
    once((
        env_get('AGENT_MOCK', "1") ->
            mock_next_reply(Reply)
        ;   ollama_chat(SysPrompt, UserPrompt, Model, Reply)
    )), !.

mock_next_reply(Reply) :-
    retract(mock_queue([H|T])) ->
        assertz(mock_queue(T)),
        Reply = H
    ;   Reply = "<done>Mock queue exhausted.</done>".

ollama_chat(SysPrompt, UserPrompt, Model, Reply) :-
    env_get('AGENT_LLM_URL', BaseUrl),
    format(string(Url), '~w/api/chat', [BaseUrl]),
    Payload = _{
        model: Model,
        stream: false,
        options: _{ num_ctx: 8192, temperature: 0.2 },
        messages: [
            _{ role: "system", content: SysPrompt },
            _{ role: "user",   content: UserPrompt }
        ]
    },
    tmp_file_stream(text, ReqFile, ReqOut),
    json_write_dict(ReqOut, Payload),
    close(ReqOut),
    tmp_file(resp, RespFile),
    catch(
        (
            atom_concat('@', ReqFile, ReqFileAtom),
            process_create(path(curl),
                ['-sS', '--max-time', '180', '-X', 'POST', Url,
                 '-H', 'Content-Type: application/json',
                 '-d', ReqFileAtom, '-o', RespFile],
                [process(PID)]),
            process_wait(PID, Status),
            (Status == exit(0) ->
                read_file_to_string(RespFile, RespStr, []),
                catch(
                    (atom_json_dict(RespStr, Dict, []),
                     Reply = Dict.get(message).get(content)),
                    _,
                    format(string(Reply), 'ERROR: llm_bad_json: ~w', [RespStr])
                )
            ;   format(string(Reply), 'ERROR: llm_http_failed (~w)', [Status])
            )
        ),
        E,
        format(string(Reply), 'ERROR: llm_exception: ~w', [E])
    ),
    safe_delete_file(ReqFile),
    safe_delete_file(RespFile).

%% shell_run(+Cmd, +TimeoutSec, -Output)
safe_delete_file(F) :-
    (exists_file(F) -> catch(delete_file(F), _, true) ; true).

to_timeout(Raw, T) :-
    (number(Raw) -> N = Raw
    ; string(Raw), number_string(N, Raw) -> true
    ; atom(Raw), atom_number(Raw, N) -> true
    ; N = 30),
    (N > 120 -> T = 120 ; N < 1 -> T = 1 ; T = N).

shell_run(Cmd, TimeoutRaw, Output) :-
    once((
        to_timeout(TimeoutRaw, TimeoutSec),
        env_get('AGENT_WORKDIR', WorkDir),
        tmp_file(sh_out, OutFile),
        % Close stdin (< /dev/null), redirect stdout+stderr to temp file to avoid pipe deadlocks
        format(string(Wrapped), 'cd "~w" && (~w) < /dev/null > "~w" 2>&1', [WorkDir, Cmd, OutFile]),
        catch(
            (
                process_create(path(sh), ['-c', Wrapped], [process(PID)]),
                process_wait(PID, Status, [timeout(TimeoutSec)]),
                (Status == timeout ->
                    ignore(process_kill(PID, kill)),
                    ignore(process_wait(PID, _)),
                    read_file_safe(OutFile, Partial),
                    format(string(Output), 'TIMEOUT after ~ws~n~w', [TimeoutSec, Partial])
                ;   read_file_safe(OutFile, Raw),
                    (Status == exit(0) ->
                        Output = Raw
                    ;   format(string(Output), 'ERROR: exit ~w~n~w', [Status, Raw])
                    )
                )
            ),
            E,
            format(string(Output), 'ERROR: shell_exception: ~w', [E])
        ),
        safe_delete_file(OutFile)
    )), !.

read_file_safe(File, Str) :-
    (exists_file(File) -> read_file_to_string(File, Str, []) ; Str = "").

%% resolve_workspace_path(+RelPath, -AbsPath)
resolve_workspace_path(RelPath, AbsPath) :-
    env_get('AGENT_WORKDIR', WorkDir),
    (is_absolute_file_name(RelPath) ->
        absolute_file_name(RelPath, AbsPath)
    ;   directory_file_path(WorkDir, RelPath, Joined),
        absolute_file_name(Joined, AbsPath)
    ).

%% path_outside_workspace(+Path, -BoolStr)
path_outside_workspace(Path, BoolStr) :-
    once((
        env_get('AGENT_WORKDIR', WorkDir),
        absolute_file_name(WorkDir, AbsWork),
        resolve_workspace_path(Path, AbsPath),
        (sub_atom(AbsPath, 0, _, _, AbsWork) -> BoolStr = "false" ; BoolStr = "true")
    )), !.

%% file_read(+Path, +Offset, +Limit, -Result)
file_read(Path, Offset, Limit, Result) :-
    once((
        resolve_workspace_path(Path, AbsPath),
        (exists_file(AbsPath) ->
            catch(
                (read_file_to_string(AbsPath, Content, []),
                 split_string(Content, "\n", "", Lines),
                 slice_lines(Lines, Offset, Limit, Sliced),
                 atomic_list_concat(Sliced, '\n', AtomRes),
                 atom_string(AtomRes, Result)),
                E,
                format(string(Result), 'ERROR: read_file: ~w', [E])
            )
        ;   format(string(Result), 'ERROR: not found: ~w', [Path])
        )
    )), !.

slice_lines(Lines, Offset, Limit, Result) :-
    (Offset > 0 -> drop_n(Offset, Lines, AfterOffset) ; AfterOffset = Lines),
    (Limit > 0  -> take_n(Limit, AfterOffset, Result) ; Result = AfterOffset).

drop_n(0, L, L) :- !.
drop_n(_, [], []) :- !.
drop_n(N, [_|T], R) :- N1 is N - 1, drop_n(N1, T, R).

take_n(0, _, []) :- !.
take_n(_, [], []) :- !.
take_n(N, [H|T], [H|R]) :- N1 is N - 1, take_n(N1, T, R).

%% file_write(+Path, +Content, -Result)
file_write(Path, Content, Result) :-
    once((
        resolve_workspace_path(Path, AbsPath),
        catch(
            (file_directory_name(AbsPath, Dir),
             make_directory_path(Dir),
             open(AbsPath, write, Out, [encoding(utf8)]),
             write(Out, Content),
             close(Out),
             string_length(Content, Len),
             format(string(Result), 'ok (~w bytes)', [Len])),
            E,
            format(string(Result), 'ERROR: write_file: ~w', [E])
        )
    )), !.

%% parse_reply(+RawReply, -ParsedTerm)
% Returns:
%   parsed(Plan, done(Summary))
%   parsed(Plan, calls(CallList))   -- up to 3 calls: call(ToolName, [arg(K,V), ...])
%   parsed(Plan, error("format"))
parse_reply(Raw, Parsed) :-
    once((
        extract_tag(Raw, "plan", Plan),
        (extract_tag(Raw, "done", Summary), Summary \= "" ->
            Parsed = [parsed, Plan, [done, Summary]]
        ;   extract_calls(Raw, Calls),
            (Calls \= [] ->
                take_n(3, Calls, Capped),
                Parsed = [parsed, Plan, [calls, Capped]]
            ;   Parsed = [parsed, Plan, [error, "format"]]
            )
        )
    )), !.

extract_tag(Text, Tag, Content) :-
    format(string(Pat), '<~w>([\\s\\S]*?)</~w>', [Tag, Tag]),
    (re_matchsub(Pat, Text, Sub, []) -> Content = Sub.1 ; Content = "").

extract_calls(Text, Calls) :-
    re_foldl(collect_call, '<call\\s+tool="([^"]+)">([\\s\\S]*?)</call>', Text, [], RevCalls, []),
    reverse(RevCalls, Calls).

collect_call(Match, Acc, [[call, Tool, Args]|Acc]) :-
    Tool = Match.1,
    Body = Match.2,
    re_foldl(collect_arg, '<arg\\s+name="([^"]+)">([\\s\\S]*?)</arg>', Body, [], RevArgs, []),
    reverse(RevArgs, Args).

collect_arg(Match, Acc, [[arg, Match.1, Match.2]|Acc]).

%% split_cmd(+Cmd, -Tokens)
split_cmd(Cmd, Tokens) :-
    once((
        re_split('[\\s;|&()]+', Cmd, Parts),
        include(non_empty_token, Parts, Tokens)
    )), !.

non_empty_token(S) :-
    S \= "",
    \+ re_match('^[\\s;|&()]+$', S).

%% redirect_overwrites_existing(+Cmd, -BoolStr)
redirect_overwrites_existing(Cmd, BoolStr) :-
    once((
        re_matchsub('(?<!>)>\\s*([^\\s;|&()]+)', Cmd, Sub, []) ->
            Target = Sub.1,
            resolve_workspace_path(Target, AbsTarget),
            (exists_file(AbsTarget) -> BoolStr = "true" ; BoolStr = "false")
        ;   BoolStr = "false"
    )), !.

%% str_truncate_middle(+Str, +HeadLen, +TailLen, -Out)
str_truncate_middle(Str, HeadLen, TailLen, Out) :-
    once((
        string_length(Str, Len),
        Max is HeadLen + TailLen,
        (Len =< Max ->
            Out = Str
        ;   Cut is Len - Max,
            sub_string(Str, 0, HeadLen, _, Head),
            TailStart is Len - TailLen,
            sub_string(Str, TailStart, TailLen, 0, Tail),
            format(string(Out), '~w~n[... ~w characters cut; use offset/limit or grep ...]~n~w',
                   [Head, Cut, Tail])
        )
    )), !.

%% str_concat_list(+List, -Out)
str_concat_list(List, Out) :-
    once((atomic_list_concat(List, '', Atom), atom_string(Atom, Out))), !.

%% trace_log(+Line, -Ack)
trace_log(Line, "ok") :-
    once((
        env_get('AGENT_TRACE', "1") ->
            format(user_error, '[TRACE] ~w~n', [Line]),
            flush_output(user_error)
        ;   true
    )), !.