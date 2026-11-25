; Load Prolog primitives FIRST so src/*.metta compile them as function calls
!(import! &self /home/avilala/PeTTa/lib/lib_import)
!(import_prolog_functions_from_file "/mnt/c/desktop/Icog/Metta_ne/metta-agent/src/prims.pl" (
    env_get llm_chat shell_run file_read file_write ask_user say
    parse_reply split_cmd path_outside_workspace redirect_overwrites_existing
    str_truncate_middle str_concat_list trace_log
))

!(import! &self src/config.metta)
!(import! &self src/policy.metta)
!(import! &self src/tools.metta)
!(import! &self src/prompt.metta)
!(import! &self src/loop.metta)
!(import! &self src/repl.metta)

!(start-repl)
