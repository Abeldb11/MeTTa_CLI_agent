; Load Prolog primitives FIRST so src/*.metta compile them as function calls
!(import! &self /home/avilala/PeTTa/lib/lib_import)
!(import_prolog_functions_from_file "/mnt/c/desktop/Icog/Metta_ne/metta-agent/src/prims.pl" (
    env_get llm_chat shell_run file_read file_write ask_user say
    parse_reply split_cmd path_outside_workspace redirect_overwrites_existing
    str_truncate_middle str_concat_list trace_log mock_set_replies
))

!(import! &self ../src/config.metta)
!(import! &self ../src/policy.metta)
!(import! &self ../src/tools.metta)
!(import! &self ../src/prompt.metta)
!(import! &self ../src/loop.metta)

(= (test-missing-file)
   (let $_ (mock_set_replies (
     "<plan>[ ] read missing</plan><call tool=\"read_file\"><arg name=\"path\">nope.txt</arg></call>"
     "<done>Handled missing file gracefully.</done>"
   ))
     (agent-loop (make-initial-state "Read nope.txt" ()))))

(= (test-unknown-tool)
   (let $_ (mock_set_replies (
     "<plan>[ ] bad tool</plan><call tool=\"fly_rocket\"><arg name=\"x\">1</arg></call>"
     "<done>Recovered from unknown tool.</done>"
   ))
     (agent-loop (make-initial-state "Test unknown tool" ()))))

(= (test-shell-timeout)
   (let $_ (mock_set_replies (
     "<plan>[ ] sleep</plan><call tool=\"run_shell\"><arg name=\"command\">sleep 100</arg><arg name=\"timeout\">2</arg></call>"
     "<done>Handled timeout.</done>"
   ))
     (agent-loop (make-initial-state "Test timeout" ()))))

(= (test-garbled-3x)
   (let $_ (mock_set_replies ("garbage 1" "garbage 2" "garbage 3"))
     (agent-loop (make-initial-state "Test garbled" ()))))

!(say "--- Running Offline Mock Tests ---")
!(say (test-missing-file))
!(say (test-unknown-tool))
!(say (test-shell-timeout))
!(say (test-garbled-3x))
