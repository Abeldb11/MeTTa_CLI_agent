; Configuration limits, model settings, and known tool table

(= (max-turns-default) 40)
(= (continue-turns-grant) 20)
(= (max-calls-per-turn) 3)
(= (shell-timeout-default) 30)
(= (shell-timeout-cap) 120)
(= (max-format-errors) 3)
(= (max-error-streak) 4)
(= (max-repeat-calls) 3)
(= (max-nudges) 2)
(= (llm-retries) 3)

; Prompt character budgets
(= (budget-goal-chars) 1200)
(= (budget-plan-chars) 1000)
(= (budget-older-turns) 30)
(= (budget-recent-turns) 5)
(= (budget-result-head) 1000)
(= (budget-result-tail) 500)
(= (budget-session-notes) 3)

; Environment-backed config
(= (get-model-name)
   (let $m (env_get "AGENT_MODEL")
     (if (== $m "") "qwen2.5:7b-instruct" $m)))

; Tool registry facts
(known-tool "read_file")
(known-tool "write_file")
(known-tool "run_shell")
(known-tool "send_message")
(known-tool "ask_user")

(= (known-tools-str) "read_file, write_file, run_shell, send_message, ask_user")

; Shared argument extractor
(= (get-arg $key $list $default)
   (if (== $list ()) $default
       (let (arg $k $v) (car-atom $list)
         (if (== $k $key) $v (get-arg $key (cdr-atom $list) $default)))))
