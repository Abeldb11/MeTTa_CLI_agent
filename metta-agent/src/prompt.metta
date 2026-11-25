; Prompt builder: fixed system prompt + budgeted goal, plan, older/recent history, and nudges

(= (system-prompt)
   "You are a CLI coding agent. You work inside the current workspace using five tools:
1. read_file(path, offset?, limit?) - read a file; use offset/limit to page through truncated output.
2. write_file(path, content) - create or overwrite a file (creates parent folders).
3. run_shell(command, timeout?) - run a shell command (default 30s, max 120s).
4. send_message(text) - print a progress note. NEVER use send_message to narrate actions; call write_file or run_shell directly. ONLY output <done>...</done> when EVERY single file and requirement in the user goal is 100% completed and verified—NEVER output <done> after an intermediate step.
5. ask_user(question) - ask the user a question and wait for their reply.

Reply using ONLY this tag format (up to 3 calls per turn):
<plan>
[x] completed step
[ ] next step
</plan>
<call tool=\"write_file\">
<arg name=\"path\">hello.py</arg>
<arg name=\"content\">print(\"hi\")</arg>
</call>

When the goal is verified and complete, reply with:
<done>Concise summary of what was accomplished.</done>

Rules:
1. Ask the user when required information is missing rather than guessing.
2. Read errors carefully and change approach instead of repeating the same call.
3. Update <plan> every turn.
4. Never claim success without verifying with a tool.
5. Emit <done> only after verification succeeds.")

(= (format-reminder)
   "ERROR: format. Reply with <plan>...</plan> and either <call tool=\"...\"><arg name=\"...\">...</arg></call> or <done>...</done>.")

; Truncate tool result keeping first 1000 and last 500 chars
(= (truncate-result $res)
   (str_truncate_middle $res (budget-result-head) (budget-result-tail)))

; Format one-line summary for older turns
(= (format-old-turn (Turn $n $tool $summary $res))
   (str_concat_list ("T" $n " " $tool " " $summary " -> " (str_truncate_middle $res 60 20) "\n")))

; Format full call + truncated result for recent turns
(= (format-recent-turn (Turn $n $tool $summary $res))
   (str_concat_list ("--- Turn " $n " ---\nCall: " $tool " (" $summary ")\nResult:\n" (truncate-result $res) "\n")))

; Render lists of turns
(= (render-old-turns $list)
   (if (== $list ()) ""
       (str_concat_list ((format-old-turn (car-atom $list)) (render-old-turns (cdr-atom $list))))))

(= (render-recent-turns $list)
   (if (== $list ()) ""
       (str_concat_list ((format-recent-turn (car-atom $list)) (render-recent-turns (cdr-atom $list))))))

(= (render-session-notes $list)
   (if (== $list ()) ""
       (str_concat_list ("- " (car-atom $list) "\n" (render-session-notes (cdr-atom $list))))))

; Build the complete user prompt from State
(= (build-user-prompt $goal $plan $old_turns $recent_turns $session_notes $nudge)
   (let $g (str_truncate_middle $goal 1000 200)
     (let $p (str_truncate_middle $plan 800 200)
       (str_concat_list (
         "GOAL:\n" $g "\n\n"
         "PLAN:\n" $p "\n\n"
         "SESSION NOTES:\n" (render-session-notes $session_notes) "\n"
         "OLDER TURNS:\n" (render-old-turns $old_turns) "\n"
         "RECENT TURNS:\n" (render-recent-turns $recent_turns) "\n"
         $nudge
       )))))
