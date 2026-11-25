; Core agent loop with explicit State threading:
; (State $goal $plan $old $recent $turn $max_turns $err_streak $fmt_streak $nudges $last_sig $rep_count $notes)

(= (make-initial-state $goal $notes)
   (State $goal "[ ] Analyze goal and plan next step" () () 1 (max-turns-default) 0 0 0 "" 0 $notes))

; Call LLM with up to 3 retries on transport failure
(= (call-llm-with-retry $sys $usr $model $attempts)
   (let $reply (llm_chat $sys $usr $model)
     (if (and (is-llm-error $reply) (> $attempts 1))
         (call-llm-with-retry $sys $usr $model (- $attempts 1))
         $reply)))

(= (is-llm-error $s)
   (or (== (str_truncate_middle $s 15 0) "ERROR: llm_http")
       (== (str_truncate_middle $s 15 0) "ERROR: llm_exce")))

; Build recovery nudge if stuck on repeats or error streaks
(= (compute-nudge $err_streak $rep_count $last_sig)
   (if (>= $rep_count (max-repeat-calls))
       (str_concat_list ("NUDGE: You repeated " $last_sig " 3 times in a row. Change approach or use ask_user.\n"))
       (if (>= $err_streak (max-error-streak))
           "NUDGE: You hit 4 errors in a row. Re-read the errors, try a different approach, or ask the user.\n"
           "")))

; Execute up to 3 tool calls in order, collecting results into recent history
(= (run-calls $calls $turn $recent $err_streak $last_sig $rep_count)
   (if (== $calls ())
       (CallsDone $recent $err_streak $last_sig $rep_count)
       (let (call $tool $args) (car-atom $calls)
         (let $res (dispatch-tool $tool $args)
           (let $_ (trace_log (str_concat_list ("T" $turn " " $tool " -> " (str_truncate_middle $res 120 40))))
             (let $sig (str_concat_list ($tool ":" (get-arg "path" $args (get-arg "command" $args ""))))
               (let $new_rep (if (== $sig $last_sig) (+ $rep_count 1) 1)
                 (let $new_err (if (== (str_truncate_middle $res 6 0) "ERROR:") (+ $err_streak 1) 0)
                   (let $entry (Turn $turn $tool $sig $res)
                     (run-calls (cdr-atom $calls) $turn (append-recent $recent $entry) $new_err $sig $new_rep))))))))))

; Keep recent list bounded (simplified append; full sliding window moves overflow to $old)
(= (append-recent $list $item)
   (if (== $list ())
       (cons-atom $item ())
       (cons-atom (car-atom $list) (append-recent (cdr-atom $list) $item))))

; Main loop step
(= (agent-loop (State $goal $plan $old $recent $turn $max_turns $err_streak $fmt_streak $nudges $last_sig $rep_count $notes))
   (if (> $turn $max_turns)
       (StuckReport (State $goal $plan $old $recent $turn $max_turns $err_streak $fmt_streak $nudges $last_sig $rep_count $notes)
                    "Turn limit reached.")
       (if (>= $nudges (max-nudges))
           (StuckReport (State $goal $plan $old $recent $turn $max_turns $err_streak $fmt_streak $nudges $last_sig $rep_count $notes)
                        "Agent remained stuck after repeated nudges.")
           (let $nudge (compute-nudge $err_streak $rep_count $last_sig)
             (let $next_nudges (if (== $nudge "") $nudges (+ $nudges 1))
               (let $usr (build-user-prompt $goal $plan $old $recent $notes $nudge)
                 (let $reply (call-llm-with-retry (system-prompt) $usr (get-model-name) (llm-retries))
                   (if (is-llm-error $reply)
                       (StuckReport (State $goal $plan $old $recent $turn $max_turns $err_streak $fmt_streak $next_nudges $last_sig $rep_count $notes)
                                    (str_concat_list ("Model endpoint unreachable: " $reply)))
                       (handle-parsed (parse_reply $reply)
                                      (State $goal $plan $old $recent $turn $max_turns $err_streak $fmt_streak $next_nudges $last_sig $rep_count $notes))))))))))

; Handle parsed LLM output
(= (handle-parsed (parsed $new_plan (done $summary)) $state)
   (DoneReport $summary))

(= (handle-parsed (parsed $new_plan (error "format"))
                  (State $goal $plan $old $recent $turn $max_turns $err_streak $fmt_streak $nudges $last_sig $rep_count $notes))
   (let $nf (+ $fmt_streak 1)
     (if (>= $nf (max-format-errors))
         (StuckReport (State $goal $plan $old $recent $turn $max_turns $err_streak $nf $nudges $last_sig $rep_count $notes)
                      "Model returned unparseable replies 3 times in a row.")
         (let $entry (Turn $turn "parse" "format" (format-reminder))
           (agent-loop (State $goal $plan $old (append-recent $recent $entry) (+ $turn 1) $max_turns (+ $err_streak 1) $nf $nudges "format" 0 $notes))))))



(= (handle-parsed (parsed $new_plan (calls $calls))
                  (State $goal $plan $old $recent $turn $max_turns $err_streak $fmt_streak $nudges $last_sig $rep_count $notes))
   (let $updated_plan (if (== $new_plan "") $plan $new_plan)
     (case (run-calls $calls $turn $recent $err_streak $last_sig $rep_count)
       (((CallsDone $new_recent $new_err $new_sig $new_rep)
         (agent-loop (State $goal $updated_plan $old $new_recent (+ $turn 1) $max_turns $new_err 0 $nudges $new_sig $new_rep $notes)))))))