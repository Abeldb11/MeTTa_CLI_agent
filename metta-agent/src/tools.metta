; Tool registry, argument extraction, policy check, and dispatch

(= (is-known-tool $name)
   (let $m (collapse (match &self (known-tool $name) True))
     (if (== $m ()) False True)))

; Extract named argument from list of (arg $k $v)
; get-arg moved to config.metta

; Clamp shell timeout to [1, 120]
(= (clamp-timeout $raw)
   (if (== $raw "") (shell-timeout-default) $raw))

; Main dispatch entry point: checks tool table, then policy gate, then runs body
(= (dispatch-tool $tool $args)
   (if (not (is-known-tool $tool))
       (str_concat_list ("ERROR: unknown tool '" $tool "'. Known tools: " (known-tools-str)))
       (case (check-policy $tool $args)
         ((Approved (run-tool-body $tool $args))
          ((Denied $msg) $msg)))))

; Tool bodies
(= (run-tool-body "read_file" $args)
   (let $path (get-arg "path" $args "")
     (if (== $path "")
         "ERROR: read_file requires 'path'"
         (let $off (get-arg "offset" $args 0)
           (let $lim (get-arg "limit" $args 0)
             (file_read $path $off $lim))))))

(= (run-tool-body "write_file" $args)
   (let $path (get-arg "path" $args "")
     (let $content (get-arg "content" $args "")
       (if (== $path "")
           "ERROR: write_file requires 'path'"
           (file_write $path $content)))))

(= (run-tool-body "run_shell" $args)
   (let $cmd (get-arg "command" $args "")
     (if (== $cmd "")
         "ERROR: run_shell requires 'command'"
         (let $t (clamp-timeout (get-arg "timeout" $args ""))
           (shell_run $cmd $t)))))

(= (run-tool-body "send_message" $args)
   (let $text (get-arg "text" $args "")
     (let $_ (say (str_concat_list ("[agent] " $text)))
       "ok (message sent)")))

(= (run-tool-body "ask_user" $args)
   (let $q (get-arg "question" $args "")
     (if (== $q "")
         "ERROR: ask_user requires 'question'"
         (ask_user (str_concat_list ("[agent asks] " $q))))))