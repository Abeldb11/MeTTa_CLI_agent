; Entry point: load Prolog primitives and MeTTa modules, then start REPL or tests

!(import! &self src/config.metta)
!(import! &self src/policy.metta)
!(import! &self src/tools.metta)
!(import! &self src/prompt.metta)
!(import! &self src/loop.metta)
!(import! &self src/repl.metta)

; Register Prolog primitives from src/prims.pl (verify exact directive in Phase 0)
!(import_prolog_function "src/prims.pl" env_get 2)
!(import_prolog_function "src/prims.pl" llm_chat 4)
!(import_prolog_function "src/prims.pl" shell_run 3)
!(import_prolog_function "src/prims.pl" file_read 4)
!(import_prolog_function "src/prims.pl" file_write 3)
!(import_prolog_function "src/prims.pl" ask_user 2)
!(import_prolog_function "src/prims.pl" say 2)
!(import_prolog_function "src/prims.pl" parse_reply 2)
!(import_prolog_function "src/prims.pl" split_cmd 2)
!(import_prolog_function "src/prims.pl" path_outside_workspace 2)
!(import_prolog_function "src/prims.pl" redirect_overwrites_existing 2)
!(import_prolog_function "src/prims.pl" str_truncate_middle 4)
!(import_prolog_function "src/prims.pl" str_concat_list 2)
!(import_prolog_function "src/prims.pl" trace_log 2)

; Start the interactive REPL
!(start-repl)