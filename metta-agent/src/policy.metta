; Safety policy: destructive command facts, workspace boundary, and approval gate

; Single-word destructive commands
(destructive "rm")
(destructive "rmdir")
(destructive "mv")
(destructive "dd")
(destructive "mkfs")
(destructive "shred")
(destructive "truncate")
(destructive "sudo")
(destructive "kill")
(destructive "pkill")
(destructive "chmod")
(destructive "chown")

; Word-pair / multi-token destructive patterns
(destructive-pair "git" "reset")
(destructive-pair "git" "clean")
(destructive-pair "git" "push")
(destructive-pair "find" "-delete")

; Check if any single token is destructive
(= (has-destructive-word $list)
   (if (== $list ()) False
       (if (is-destructive-word (car-atom $list))
           True
           (has-destructive-word (cdr-atom $list)))))

(= (is-destructive-word $w)
   (let $m (collapse (match &self (destructive $w) True))
     (if (== $m ()) False True)))

; Check adjacent or co-occurring destructive pairs
(= (has-destructive-pair $list)
   (if (== $list ()) False
       (let $rest (cdr-atom $list)
         (if (== $rest ()) False
             (if (is-destructive-pair (car-atom $list) (car-atom $rest))
                 True
                 (has-destructive-pair $rest))))))

(= (is-destructive-pair $a $b)
   (let $m (collapse (match &self (destructive-pair $a $b) True))
     (if (== $m ()) False True)))

; Shell command needs approval?
(= (shell-needs-approval $cmd)
   (let $tokens (split_cmd $cmd)
     (if (has-destructive-word $tokens)
         True
         (if (has-destructive-pair $tokens)
             True
             (== (redirect_overwrites_existing $cmd) "true")))))

; File path needs approval?
(= (path-needs-approval $path)
   (== (path_outside_workspace $path) "true"))

; Request explicit y/N approval from the user
(= (request-approval $desc)
   (let $ans (ask_user (str_concat_list ("[APPROVAL REQUIRED] " $desc " — Allow? (y/N):")))
     (if (== $ans "y")
         Approved
         (Denied (str_concat_list ("DENIED by user: " $desc ". Pick a non-destructive alternative or ask the user."))))))

; Unified policy gate called before tool execution
(= (check-policy "run_shell" $args)
   (let $cmd (get-arg "command" $args "")
     (if (shell-needs-approval $cmd)
         (request-approval $cmd)
         Approved)))

(= (check-policy "read_file" $args)
   (let $p (get-arg "path" $args "")
     (if (path-needs-approval $p)
         (request-approval (str_concat_list ("read_file outside workspace: " $p)))
         Approved)))

(= (check-policy "write_file" $args)
   (let $p (get-arg "path" $args "")
     (if (path-needs-approval $p)
         (request-approval (str_concat_list ("write_file outside workspace: " $p)))
         Approved)))

(= (check-policy "send_message" $args) Approved)
(= (check-policy "ask_user" $args) Approved)