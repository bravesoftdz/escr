{   Routines for manipulating ESCR system use states.
*
*   For a application to use the ESCR system, it must create a use state, use
*   the system, then delete the use state.  The application maintains the
*   pointer to the use state, and passes it to all ESCR routines.
}
module escr_open;
define escr_open;
define escr_close;
define escr_set_incsuff;
%include 'escr2.ins.pas';
{
********************************************************************************
*
*   Subroutine ESCR_OPEN (MEM, E_P, STAT)
*
*   Create a new ESCR system use state.  This must be the first routine called
*   for any use of the ESCR system.
*
*   MEM is the parent memory context within which all new dynamic memory will be
*   allocated.  Only a single sub-context will be added directly to MEM.
*
*   E_P is return pointing to the new ESCR system use state.  This pointer must
*   be maintained by the application, and passed to each ESCR routine it calls
*   for this use of the system.  If the new use state can not be created for
*   some reason, then E_P will be returned NIL and STAT will indicate the error
*   condition.
}
procedure escr_open (                  {start a new use of the ESCR system}
  in out  mem: util_mem_context_t;     {parent memory context, will make sub context}
  out     e_p: escr_p_t;               {will point to new initialized ESCR use state}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  mem_p: util_mem_context_p_t;         {pointer to new top memory context}

label
  err_nocontext, err;
{
******************************
*
*   Subroutine ADDCMD (NAME, ROUTINE_P, STAT)
*   This routine is local to ESCR_OPEN.
*
*   Add the intrinsic command NAME to the commands symbol table.  NAME is a
*   Pascal string, not a var string.  ROUTINE_P is the pointer to the command
*   routine.
}
type
  {
  *   A separate template for a command routine is defined here.  This is the
  *   same as the official ESCR_ICMD_P_T except that the first argument is the
  *   library use state directly defined for IN and OUT use, as apposed to a
  *   pointer to the library use state.  The former is how command routines are
  *   actually defined, but the ESCR_ICMD_P_T template can't be defined that way
  *   due to circular dependencies that would be required of such a definition.
  *   Both definitions should result in the same code.
  }
  cmd_routine_p_t = ^procedure (
    in out e: escr_t;
    out   stat: sys_err_t);
    val_param;

procedure addcmd (                     {add intrinsic command to commands table}
  in      name: string;                {command name}
  in      routine_p: cmd_routine_p_t;  {pointer to command routine}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  escr_icmd_add (                      {add intrinsic command to commands table}
    e_p^,                              {state for this use of the ESCR library}
    string_v(name),                    {command name}
    escr_icmd_p_t(routine_p),          {pointer to command routine}
    stat);
  end;
{
******************************
*
*   Subroutine ADDFUNC (NAME, ROUTINE_P, STAT)
*   This routine is local to ESCR_OPEN.
*
*   Add the intrinsic function NAME to the functions symbol table.  NAME is a
*   Pascal string, not a var string.  ROUTINE_P is the pointer to the function
*   routine.
}
type
  {
  *   A separate template for a function routine is defined here.  This is the
  *   same as the official ESCR_IFUNC_P_T except that the first argument is the
  *   library use state directly defined for IN and OUT use, as apposed to a
  *   pointer to the library use state.  The former is how function routines are
  *   actually defined, but the ESCR_IFUNC_P_T template can't be defined that
  *   way due to circular dependencies that would be required of such a
  *   definition.  Both definitions should result in the same code.
  }
  func_routine_p_t = ^procedure (
    in out e: escr_t;                  {library use state}
    out   stat: sys_err_t);
    val_param;

procedure addfunc (                    {add intrinsic function to functions table}
  in      name: string;                {function name}
  in      function_p: func_routine_p_t; {pointer to function routine}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  escr_ifunc_add (                     {add intrinsic function to functions table}
    e_p^,                              {state for this use of the ESCR library}
    string_v(name),                    {function name}
    escr_ifunc_p_t(function_p),        {pointer to function routine}
    stat);
  end;
{
******************************
*
*   Start of ESCR_OPEN.
}
begin
  sys_error_none (stat);               {init to no error encountered}

  util_mem_context_get (mem, mem_p);   {create top mem context for this ESCR use}
  if mem_p = nil then goto err_nocontext; {unable to create new memory context ?}

  util_mem_grab (sizeof(e_p^), mem_p^, false, e_p); {create the new state block}
  if e_p = nil then begin              {couldn't get the memory ?}
    sys_stat_set (escr_subsys_k, escr_err_nomem_k, stat);
    sys_stat_parm_int (sizeof(e_p^), stat);
    goto err;
    end;
  e_p^.mem_p := mem_p;                 {save pointer to our top mem context}

  escr_sytable_init (e_p^.mem_p^, e_p^.sym_var, stat); {init variables/constants symbol table}
  if sys_error(stat) then goto err;
  escr_sytable_init (e_p^.mem_p^, e_p^.sym_sub, stat); {init subroutines symbol table}
  if sys_error(stat) then goto err;
  escr_sytable_init (e_p^.mem_p^, e_p^.sym_mac, stat); {init macros symbol table}
  if sys_error(stat) then goto err;
  escr_sytable_init (e_p^.mem_p^, e_p^.sym_fun, stat); {init functions symbol table}
  if sys_error(stat) then goto err;
  escr_sytable_init (e_p^.mem_p^, e_p^.sym_cmd, stat); {init commands symbol table}
  if sys_error(stat) then goto err;
  escr_sytable_init (e_p^.mem_p^, e_p^.sym_lab, stat); {init labels symbol table}
  if sys_error(stat) then goto err;
  escr_sytable_init (e_p^.mem_p^, e_p^.sym_src, stat); {init source code snippets symbol table}
  if sys_error(stat) then goto err;
{
*   Do basic initialization.
}
  e_p^.files_p := nil;
  e_p^.ibuf.max := size_char(e_p^.ibuf.str);
  e_p^.ibuf.len := 0;
  e_p^.funarg.p := 1;
  e_p^.funarg.s.max := size_char(e_p^.funarg.s.str);
  e_p^.funarg.s.len := 0;
  e_p^.funame.max := size_char(e_p^.funame.str);
  e_p^.funame.len := 0;
  e_p^.funret.max := size_char(e_p^.funret.str);
  e_p^.funret.len := 0;
  e_p^.ip := 1;
  e_p^.lparm.max := size_char(e_p^.lparm.str);
  e_p^.lparm.len := 0;
  e_p^.cmd.max := size_char(e_p^.cmd.str);
  e_p^.cmd.len := 0;
  e_p^.exblock_p := nil;
  e_p^.inhroot.prev_p := nil;
  e_p^.inhroot.inh := false;
  e_p^.inhroot.inhty := escr_inhty_root_k;
  e_p^.inhibit_p := addr(e_p^.inhroot);
  e_p^.out_p := nil;
  e_p^.obuf.max := size_char(e_p^.obuf.str);
  e_p^.obuf.len := 0;
  e_p^.ulabn := 1;
  e_p^.incsuff := '';
  e_p^.cmdst.max := size_char(e_p^.cmdst.str);
  e_p^.cmdst.len := 0;
  e_p^.syexcl_p := nil;
  e_p^.commscr_p := nil;
  e_p^.commdat_p := nil;
  e_p^.syfunc.st.max := size_char(e_p^.syfunc.st.str);
  string_vstring (e_p^.syfunc.st, '[', 1);
  e_p^.syfunc.en.max := size_char(e_p^.syfunc.en.str);
  string_vstring (e_p^.syfunc.en, ']', 1);
  e_p^.syfunc_st_p := nil;
  e_p^.flags := [];
  e_p^.exstat := 0;
{
*   Do higher level initialization now that all fields have at least legal
*   values.
}
  escr_commscr_add (                   {init to default ESCR comments}
    e_p^,                              {state for this use of the ESCR system}
    string_v('//'),                    {comment start}
    string_v(''),                      {comment ends at end of line}
    stat);
  if sys_error(stat) then goto err;

  escr_syexcl_add (                    {add exclusion for double quoted strings}
    e_p^,                              {state for this use of the ESCR system}
    string_v('"'),                     {quoted string start}
    string_v('"'),                     {quoted string end}
    stat);
  if sys_error(stat) then goto err;

  escr_syexcl_add (                    {add exclusion for single quoted strings}
    e_p^,                              {state for this use of the ESCR system}
    string_v(''''),                    {quoted string start}
    string_v(''''),                    {quoted string end}
    stat);
  if sys_error(stat) then goto err;
  {
  *   Add the standard commands to the commands symbol table.
  }
  addcmd ('BLOCK', addr(escr_cmd_block), stat); if sys_error(stat) then goto err;
  addcmd ('CALL', addr(escr_cmd_call), stat); if sys_error(stat) then goto err;
  addcmd ('CONST', addr(escr_cmd_const), stat); if sys_error(stat) then goto err;
  addcmd ('DEL', addr(escr_cmd_del), stat); if sys_error(stat) then goto err;
  addcmd ('ELSE', addr(escr_cmd_else), stat); if sys_error(stat) then goto err;
  addcmd ('ENDBLOCK', addr(escr_cmd_endblock), stat); if sys_error(stat) then goto err;
  addcmd ('ENDIF', addr(escr_cmd_endif), stat); if sys_error(stat) then goto err;
  addcmd ('ENDLOOP', addr(escr_cmd_endloop), stat); if sys_error(stat) then goto err;
  addcmd ('ENDMAC', addr(escr_cmd_endmac), stat); if sys_error(stat) then goto err;
  addcmd ('ENDSUB', addr(escr_cmd_endsub), stat); if sys_error(stat) then goto err;
  addcmd ('IF', addr(escr_cmd_if), stat); if sys_error(stat) then goto err;
  addcmd ('INCLUDE', addr(escr_cmd_include), stat); if sys_error(stat) then goto err;
  addcmd ('LOOP', addr(escr_cmd_loop), stat); if sys_error(stat) then goto err;
  addcmd ('MACRO', addr(escr_cmd_macro), stat); if sys_error(stat) then goto err;
  addcmd ('QUIT', addr(escr_cmd_quit), stat); if sys_error(stat) then goto err;
  addcmd ('QUITMAC', addr(escr_cmd_quitmac), stat); if sys_error(stat) then goto err;
  addcmd ('REPEAT', addr(escr_cmd_repeat), stat); if sys_error(stat) then goto err;
  addcmd ('RETURN', addr(escr_cmd_return), stat); if sys_error(stat) then goto err;
  addcmd ('SET', addr(escr_cmd_set), stat); if sys_error(stat) then goto err;
  addcmd ('SHOW', addr(escr_cmd_show), stat); if sys_error(stat) then goto err;
  addcmd ('STOP', addr(escr_cmd_stop), stat); if sys_error(stat) then goto err;
  addcmd ('SUBROUTINE', addr(escr_cmd_subroutine), stat); if sys_error(stat) then goto err;
  addcmd ('SYLIST', addr(escr_cmd_sylist), stat); if sys_error(stat) then goto err;
  addcmd ('THEN', addr(escr_cmd_then), stat); if sys_error(stat) then goto err;
  addcmd ('VAR', addr(escr_cmd_var), stat); if sys_error(stat) then goto err;
  addcmd ('WRITE', addr(escr_cmd_write), stat); if sys_error(stat) then goto err;
  addcmd ('WRITEPOP', addr(escr_cmd_writepop), stat); if sys_error(stat) then goto err;
  addcmd ('WRITEPUSH', addr(escr_cmd_writepush), stat); if sys_error(stat) then goto err;
  addcmd ('RUN', addr(escr_cmd_run), stat); if sys_error(stat) then goto err;
  {
  *   Add the intrinsic functions to the functions symbol table.
  }
  addfunc ('ABS', addr(escr_ifun_abs), stat); if sys_error(stat) then goto err;
  addfunc ('AND', addr(escr_ifun_and), stat); if sys_error(stat) then goto err;
  addfunc ('ARG', addr(escr_ifun_arg), stat); if sys_error(stat) then goto err;
  addfunc ('CCODE', addr(escr_ifun_ccode), stat); if sys_error(stat) then goto err;
  addfunc ('CHAR', addr(escr_ifun_char), stat); if sys_error(stat) then goto err;
  addfunc ('CHARS', addr(escr_ifun_chars), stat); if sys_error(stat) then goto err;
  addfunc ('COS', addr(escr_ifun_cos), stat); if sys_error(stat) then goto err;
  addfunc ('DATE', addr(escr_ifun_date), stat); if sys_error(stat) then goto err;
  addfunc ('DEGR', addr(escr_ifun_degr), stat); if sys_error(stat) then goto err;
  addfunc ('DIV', addr(escr_ifun_div), stat); if sys_error(stat) then goto err;
  addfunc ('/', addr(escr_ifun_divide), stat); if sys_error(stat) then goto err;
  addfunc ('E', addr(escr_ifun_e), stat); if sys_error(stat) then goto err;
  addfunc ('ENG', addr(escr_ifun_eng), stat); if sys_error(stat) then goto err;
  addfunc ('=', addr(escr_ifun_eq), stat); if sys_error(stat) then goto err;
  addfunc ('EVAR', addr(escr_ifun_evar), stat); if sys_error(stat) then goto err;
  addfunc ('EXIST', addr(escr_ifun_exist), stat); if sys_error(stat) then goto err;
  addfunc ('EXP', addr(escr_ifun_exp), stat); if sys_error(stat) then goto err;
  addfunc ('FP', addr(escr_ifun_fp), stat); if sys_error(stat) then goto err;
  addfunc ('>=', addr(escr_ifun_ge), stat); if sys_error(stat) then goto err;
  addfunc ('>', addr(escr_ifun_gt), stat); if sys_error(stat) then goto err;
  addfunc ('IF', addr(escr_ifun_if), stat); if sys_error(stat) then goto err;
  addfunc ('INT', addr(escr_ifun_int), stat); if sys_error(stat) then goto err;
  addfunc ('~', addr(escr_ifun_inv), stat); if sys_error(stat) then goto err;
  addfunc ('ISINT', addr(escr_ifun_isint), stat); if sys_error(stat) then goto err;
  addfunc ('ISNUM', addr(escr_ifun_isnum), stat); if sys_error(stat) then goto err;
  addfunc ('LAB', addr(escr_ifun_lab), stat); if sys_error(stat) then goto err;
  addfunc ('LCASE', addr(escr_ifun_lcase), stat); if sys_error(stat) then goto err;
  addfunc ('<=', addr(escr_ifun_le), stat); if sys_error(stat) then goto err;
  addfunc ('LNAM', addr(escr_ifun_lnam), stat); if sys_error(stat) then goto err;
  addfunc ('LOG', addr(escr_ifun_log), stat); if sys_error(stat) then goto err;
  addfunc ('LOG2', addr(escr_ifun_log2), stat); if sys_error(stat) then goto err;
  addfunc ('<', addr(escr_ifun_lt), stat); if sys_error(stat) then goto err;
  addfunc ('MAX', addr(escr_ifun_max), stat); if sys_error(stat) then goto err;
  addfunc ('MIN', addr(escr_ifun_min), stat); if sys_error(stat) then goto err;
  addfunc ('-', addr(escr_ifun_minus), stat); if sys_error(stat) then goto err;
  addfunc ('<>', addr(escr_ifun_ne), stat); if sys_error(stat) then goto err;
  addfunc ('NOT', addr(escr_ifun_not), stat); if sys_error(stat) then goto err;
  addfunc ('NOW', addr(escr_ifun_now), stat); if sys_error(stat) then goto err;
  addfunc ('OR', addr(escr_ifun_or), stat); if sys_error(stat) then goto err;
  addfunc ('PI', addr(escr_ifun_pi), stat); if sys_error(stat) then goto err;
  addfunc ('+', addr(escr_ifun_plus), stat); if sys_error(stat) then goto err;
  addfunc ('1+', addr(escr_ifun_postinc), stat); if sys_error(stat) then goto err;
  addfunc ('1-', addr(escr_ifun_postdec), stat); if sys_error(stat) then goto err;
  addfunc ('+1', addr(escr_ifun_preinc), stat); if sys_error(stat) then goto err;
  addfunc ('-1', addr(escr_ifun_predec), stat); if sys_error(stat) then goto err;
  addfunc ('QSTR', addr(escr_ifun_qstr), stat); if sys_error(stat) then goto err;
  addfunc ('RDEG', addr(escr_ifun_rdeg), stat); if sys_error(stat) then goto err;
  addfunc ('RND', addr(escr_ifun_rnd), stat); if sys_error(stat) then goto err;
  addfunc ('SEQ', addr(escr_ifun_seq), stat); if sys_error(stat) then goto err;
  addfunc ('SHIFTL', addr(escr_ifun_shiftl), stat); if sys_error(stat) then goto err;
  addfunc ('SHIFTR', addr(escr_ifun_shiftr), stat); if sys_error(stat) then goto err;
  addfunc ('SIN', addr(escr_ifun_sin), stat); if sys_error(stat) then goto err;
  addfunc ('SINDX', addr(escr_ifun_sindx), stat); if sys_error(stat) then goto err;
  addfunc ('SLEN', addr(escr_ifun_slen), stat); if sys_error(stat) then goto err;
  addfunc ('SQRT', addr(escr_ifun_sqrt), stat); if sys_error(stat) then goto err;
  addfunc ('STR', addr(escr_ifun_str), stat); if sys_error(stat) then goto err;
  addfunc ('SUBSTR', addr(escr_ifun_substr), stat); if sys_error(stat) then goto err;
  addfunc ('SYM', addr(escr_ifun_sym), stat); if sys_error(stat) then goto err;
  addfunc ('TAN', addr(escr_ifun_tan), stat); if sys_error(stat) then goto err;
  addfunc ('*', addr(escr_ifun_times), stat); if sys_error(stat) then goto err;
  addfunc ('TNAM', addr(escr_ifun_tnam), stat); if sys_error(stat) then goto err;
  addfunc ('TRUNC', addr(escr_ifun_trunc), stat); if sys_error(stat) then goto err;
  addfunc ('UCASE', addr(escr_ifun_ucase), stat); if sys_error(stat) then goto err;
  addfunc ('UNQUOTE', addr(escr_ifun_unquote), stat); if sys_error(stat) then goto err;
  addfunc ('V', addr(escr_ifun_v), stat); if sys_error(stat) then goto err;
  addfunc ('XOR', addr(escr_ifun_xor), stat); if sys_error(stat) then goto err;

  return;

err_nocontext:                         {could not get new memory context}
  sys_stat_set (escr_subsys_k, escr_err_nomcontext_k, stat);

err:                                   {return with error, STAT already set}
  if mem_p <> nil then begin           {our mem context was created ?}
    util_mem_context_del (mem_p);      {yes, delete all our dynamic memory}
    end;
  e_p := nil;                          {indicate the new state was not created}
  end;
{
********************************************************************************
*
*   Subroutine ESCR_CLOSE (E_P)
*
*   End a use of the ESCR system.  E_P must point to a previously-created ESCR
*   system use state.  All system resources allocated to the use state will be
*   released, and E_P will be returned NIL.
}
procedure escr_close (                 {end a use of the ESCR system}
  in out  e_p: escr_p_t);              {pointer to ESCR use state, returned NIL}
  val_param;

var
  mem_p: util_mem_context_p_t;         {pointer to new top memory context}

begin
  if e_p = nil then return;            {no state to deallocate ?}

  escr_out_close_all (e_p^, false);    {close all output files}

  mem_p := e_p^.mem_p;                 {get pointer to top memory context}
  util_mem_context_del (mem_p);        {delete the mem context}

  e_p := nil;                          {indicate use state no longer exists}
  end;
{
********************************************************************************
*
*   Subroutine ESCR_INCSUFF (E, SUFF)
*
*   Sets the list of allowed suffixes of include file names.  Each suffix is
*   blank-separated.  SUFF of all blank requires the include file name to be
*   exactly as specified.  This can also be one option when suffixes are
*   supplied by adding the suffix "" (in quotes).
}
procedure escr_set_incsuff (           {set allowed suffixes for include file names}
  in out  e: escr_t;                   {state for this use of the ESCR system}
  in      suff: string);               {suffixes, blank separated}
  val_param;

begin
  e.incsuff := suff;
  end;
