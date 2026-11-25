; Idle REPL loop between tasks; supports 'exit' and 'continue' (+20 turns)

(= (start-repl)
   (let $_ (say "MeTTa CLI Agent ready. Enter a task, or 'exit' to quit.")
     (repl-loop () None)))

(= (repl-loop $session_notes $paused_state)
   (let $input (ask_user "agent>")
     (if (or (== $input "exit") (== $input "quit"))
         (say "Goodbye.")
         (if (== $input "")
             (repl-loop $session_notes $paused_state)
             (if (and (== $input "continue") (not (== $paused_state None)))
                 (resume-task $paused_state $session_notes)
                 (run-new-task $input $session_notes))))))

(= (run-new-task $goal $session_notes)
   (let $init (make-initial-state $goal $session_notes)
     (handle-task-outcome (agent-loop $init) $goal $session_notes)))

(= (resume-task (State $goal $plan $old $recent $turn $max_turns $err $fmt $nudges $sig $rep $notes) $session_notes)
   (let $extended (State $goal $plan $old $recent $turn (+ $max_turns (continue-turns-grant)) 0 0 0 "" 0 $notes)
     (handle-task-outcome (agent-loop $extended) $goal $session_notes)))

(= (handle-task-outcome (DoneReport $summary) $goal $session_notes)
   (let $_ (say (str_concat_list ("\n[DONE] " $summary "\n")))
     (let $note (str_concat_list ($goal " -> " (str_truncate_middle $summary 80 0)))
       (repl-loop (cons-atom $note $session_notes) None))))

(= (handle-task-outcome (StuckReport $state $reason) $goal $session_notes)
   (let $_ (say (str_concat_list ("\n[STUCK] " $reason "\nType 'continue' for 20 more turns, or enter a new task.\n")))
     (repl-loop $session_notes $state)))