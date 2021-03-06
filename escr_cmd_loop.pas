{   Commands related to loops.
}
module escr_cmd_loop;
define escr_cmd_loop;
define escr_loop_iter;
define escr_cmd_endloop;
%include 'escr2.ins.pas';
{
********************************************************************************
*
*   Local subroutine ADDLIST (LIST, TABLE, STYPES)
*
*   Add all the symbols in the symbol table TABLE that are one of the types in
*   STYPES to the string list LIST.  The string list entries will be the fully
*   qualified symbol names.
}
procedure addlist (                    {add to symbols list}
  in out  list: string_list_t;         {the list to add symbol names to}
  in      table: escr_sytable_t;       {the symbol table to look for symbols in}
  in      stypes: escr_symty_t);       {set of symbol types to add, others ignored}
  val_param; internal;

var
  scan: escr_sytable_scan_t;           {state for scanning symbol table}
  name_p: string_var_p_t;              {pointer to symbol name in table}
  ent_p: escr_sytable_data_p_t;        {pointer to symbol data in table}
  sym_p: escr_sym_p_t;                 {pointer to current symbol}
  name: string_var132_t;               {variable name}

begin
  name.max := size_char(name.str);     {init local var string}

  escr_sytable_scan_start (table, scan); {init symbol table scanning state}
  while true do begin                  {once for each symbol in the symbol table}
    escr_sytable_scan (scan, name_p, ent_p); {get this next symbol table entry}
    if ent_p = nil then exit;          {hit end of table ?}
    sym_p := ent_p^.curr_p;            {get pointer to current version of symbol}
    if sym_p = nil then next;          {no curr version, default doesn't exist ?}
    if sym_p^.stype in stypes then begin {include this symbol in list ?}
      escr_sym_name (sym_p^, name);    {make fully qualified symbol name}
      list.size := name.len;           {set size of this new string}
      string_list_line_add (list);     {create the new names list entry}
      string_copy (name, list.str_p^); {fill in this list entry}
      end;
    end;
  end;
{
********************************************************************************
*
*   Subroutine  ESCR_CMD_LOOP (E, STAT)
*
*   LOOP
*
*   LOOP SYMBOLS var [VAR CONST VCON SUBR MACRO FUNC CMD LABEL]
*
*   LOOP [WITH var] [FROM n] [TO n] [BY n] [N n]
}
procedure escr_cmd_loop (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param;

type
  keyw_k_t = (                         {ID for each keyword}
    keyw_symbols_k,
    keyw_with_k,
    keyw_from_k,
    keyw_to_k,
    keyw_by_k,
    keyw_n_k);
  keyw_t = set of keyw_k_t;            {set of all possible keywords}

var
  keyw: keyw_t;                        {keywords seen so far}
  loop_p: escr_loop_p_t;               {pointer to loop descriptor}
  pick: sys_int_machine_t;             {number of keyword picked from list}
  n_n: sys_int_machine_t;              {value with N keyword}
  name: string_var80_t;                {variable name}
  tk: string_var32_t;                  {scratch token}
  sym_p: escr_sym_p_t;                 {pointer to symbol name}
  slist_p: string_list_p_t;            {points to strings list}
  sytypes: escr_sytype_t;              {set of user-visible symbol types}
  symty: escr_symty_t;                 {set of internal symbol types}
  stat2: sys_err_t;                    {to avoid corrupting STAT}

label
  err_missing, err_keyw, err_abort;

begin
  name.max := size_char(name.str);     {init local var string}
  tk.max := size_char(tk.str);
  sys_error_none (stat);               {init to no error occurred}

  escr_exblock_new (e, stat);          {create new execution block state}
  if sys_error(stat) then return;
  e.exblock_p^.start_p :=              {save pointer to starting line of this block}
    e.exblock_p^.prev_p^.inpos_p^.last_p;
  e.exblock_p^.bltype := escr_exblock_loop_k; {indicate LOOP ... ENDLOOP type}
  escr_exblock_inline_set (            {set next source line to execute}
    e, e.exblock_p^.prev_p^.inpos_p^.line_p, stat);
  if sys_error(stat) then return;

  if e.inhibit_p^.inh then return;     {execution inhibited ?}

  util_mem_grab (                      {allocate loop descriptor}
    sizeof(loop_p^), e.exblock_p^.mem_p^, false, loop_p);
  loop_p^.looptype := escr_looptype_unc_k; {init loop descriptor to default}
  e.exblock_p^.loop_p := loop_p;       {add loop descriptor to this execution block}

  keyw := [];                          {init to no keywords found}

  while true do begin                  {back here until command line exhausted}
    if not escr_get_token (e, tk)      {get next command line token into TK}
      then exit;                       {exhausted the command line ?}
    string_upcase (tk);                {make upper case for keyword matching}
    string_tkpick80 (tk,               {pick the keyword from list}
      'SYMBOLS WITH FROM TO BY N',
      pick);
    case pick of                       {which keyword is it ?}
{
******************************
*
*   SYMBOLS const [VAR CONST VCON SUBR MACRO FUNC CMD LABEL]
}
1: begin
  if loop_p^.looptype <> escr_looptype_unc_k {incompatible with previous keyword ?}
    then goto err_keyw;
  if keyw_symbols_k in keyw
    then goto err_keyw;
  keyw := keyw + [keyw_symbols_k];     {record that this keyword used}

  loop_p^.looptype := escr_looptype_sym_k; {looping over list of symbols}

  if not escr_get_token (e, name)      {get the variable name into NAME}
    then goto err_missing;
{
*   Read the optional list of symbol types.  SYTYPES is set to the set of
*   requested symbol types.  SYTYPES is initialized to the empty set.  If it
*   remains the empty set, then no specific types were requested and all types
*   will be listed.
*
*   The remainder of the command line will be read.  All remaining tokens must
*   be symbol type specifiers.
}
  sytypes := [];                       {init to no specific symbols requested}

  while true do begin                  {back here to get each new type specifier}
    escr_get_keyword (e,
      'VAR CONST VCON SUBR MACRO FUNC CMD LABEL',
      pick, stat);
    if pick = 0 then exit;             {hit end of the command line ?}
    if sys_error(stat) then goto err_abort; {hard error ?}
    case pick of
1:    sytypes := sytypes + [escr_sytype_var_k];
2:    sytypes := sytypes + [escr_sytype_const_k];
3:    sytypes := sytypes + [escr_sytype_var_k, escr_sytype_const_k];
4:    sytypes := sytypes + [escr_sytype_subr_k];
5:    sytypes := sytypes + [escr_sytype_macro_k];
6:    sytypes := sytypes + [escr_sytype_func_k];
7:    sytypes := sytypes + [escr_sytype_cmd_k];
8:    sytypes := sytypes + [escr_sytype_label_k];
      end;
    end;                               {back to get next symbol type keyword}

  if sytypes = [] then begin           {no symbol types specified ?}
    sytypes := [                       {list symbols of all types}
      escr_sytype_var_k,
      escr_sytype_const_k,
      escr_sytype_subr_k,
      escr_sytype_macro_k,
      escr_sytype_func_k,
      escr_sytype_cmd_k,
      escr_sytype_label_k];
    end;
{
*   Create the local list of symbol names.
}
  util_mem_grab (                      {allocate symbol names list}
    sizeof(slist_p^), e.exblock_p^.mem_p^, false, slist_p);
  loop_p^.sym_list_p := slist_p;       {save pointer to names list}

  string_list_init (slist_p^, e.exblock_p^.mem_p^); {init names list}
  slist_p^.deallocable := false;       {not individually deacllocatable}

  symty := [];                         {init to neither variables or constants}
  if escr_sytype_var_k in sytypes then begin
    symty := symty + [escr_sym_var_k];
    end;
  if escr_sytype_const_k in sytypes then begin
    symty := symty + [escr_sym_const_k];
    end;
  if symty <> [] then begin            {list variables and/or constants ?}
    addlist (slist_p^, e.sym_var, symty);
    end;

  if escr_sytype_subr_k in sytypes then begin
    addlist (slist_p^, e.sym_sub, [escr_sym_subr_k, escr_sym_isubr_k]);
    end;
  if escr_sytype_macro_k in sytypes then begin
    addlist (slist_p^, e.sym_mac, [escr_sym_macro_k, escr_sym_imacro_k]);
    end;
  if escr_sytype_func_k in sytypes then begin
    addlist (slist_p^, e.sym_fun, [escr_sym_func_k, escr_sym_ifunc_k]);
    end;
  if escr_sytype_cmd_k in sytypes then begin
    addlist (slist_p^, e.sym_cmd, [escr_sym_cmd_k, escr_sym_icmd_k]);
    end;
  if escr_sytype_label_k in sytypes then begin
    addlist (slist_p^, e.sym_lab, [escr_sym_label_k]);
    end;

  string_list_sort (                   {sort the list of symbol names}
    slist_p^,                          {the list to sort}
    [string_comp_num_k]);              {compare numeric fields numerically}
{
*   Initialze the loop state to the first names list entry.
}
  escr_sym_new_const (                 {create the iteration value constant}
    e,                                 {state for this use of the ESCR system}
    name,                              {name of variable to create}
    escr_dtype_str_k,                  {variable's data type}
    escr_max_namelen_k,                {max length}
    false,                             {local, not global}
    sym_p,                             {returned pointer to the new variable}
    stat);
  if sys_error(stat) then goto err_abort;
  loop_p^.sym_const_p := sym_p;        {save pointer to iteration value constant}

  string_list_pos_abs (slist_p^, 1);   {go to first list entry}

  if slist_p^.str_p = nil then begin   {the list is empty ?}
    e.inhibit_p^.inh := true;          {inhibit execution for this block}
    return;
    end;

  string_copy (                        {init loop value to first symbol name}
    slist_p^.str_p^, loop_p^.sym_const_p^.const_val.str);
  end;                                 {end of SYMBOL keyword case}
{
******************************
*
*   WITH const
}
2: begin
  if loop_p^.looptype = escr_looptype_unc_k then begin {loop type not set yet ?}
    loop_p^.looptype := escr_looptype_cnt_k; {is now a counted loop}
    loop_p^.cnt_inf := true;
    end;
  if loop_p^.looptype <> escr_looptype_cnt_k {wrong loop type for this keyword ?}
    then goto err_keyw;
  if keyw_with_k in keyw               {this keyword already used before ?}
    then goto err_keyw;
  keyw := keyw + [keyw_with_k];        {record that this keyword used}

  if not escr_get_token (e, name)      {get the constant name into NAME}
    then goto err_missing;

  escr_sym_new_const (                 {create the iteration value constant}
    e,                                 {state for this use of the ESCR system}
    name,                              {name of the variable to create}
    escr_dtype_int_k,                  {data type will be integer}
    0,                                 {additional length parameter, unused}
    false,                             {will be local, not global}
    sym_p,                             {returned pointer to the new symbol}
    stat);
  if sys_error(stat) then goto err_abort;
  loop_p^.cnt_const_p := sym_p;        {save pointer to the iteration value constant}
  end;
{
******************************
*
*   FROM n
}
3: begin
  if loop_p^.looptype = escr_looptype_unc_k then begin {loop type not set yet ?}
    loop_p^.looptype := escr_looptype_cnt_k; {is now a counted loop}
    loop_p^.cnt_const_p := nil;
    loop_p^.cnt_inf := true;
    end;
  if loop_p^.looptype <> escr_looptype_cnt_k {wrong loop type for this keyword ?}
    then goto err_keyw;
  if keyw_from_k in keyw               {this keyword already used before ?}
    then goto err_keyw;
  keyw := keyw + [keyw_from_k];        {record that this keyword used}

  if not escr_get_int (e, loop_p^.cnt_start, stat) {get N}
    then goto err_missing;
  if sys_error(stat) then goto err_abort;
  end;
{
******************************
*
*   TO n
}
4: begin
  if loop_p^.looptype = escr_looptype_unc_k then begin {loop type not set yet ?}
    loop_p^.looptype := escr_looptype_cnt_k; {is now a counted loop}
    loop_p^.cnt_const_p := nil;
    end;
  if loop_p^.looptype <> escr_looptype_cnt_k {wrong loop type for this keyword ?}
    then goto err_keyw;
  if keyw_to_k in keyw                 {this keyword already used before ?}
    then goto err_keyw;
  keyw := keyw + [keyw_to_k];          {record that this keyword used}

  if not escr_get_int (e, loop_p^.cnt_end, stat) {get N}
    then goto err_missing;
  if sys_error(stat) then goto err_abort;
  loop_p^.cnt_inf := false;            {this loop has definite end}
  end;
{
******************************
*
*   BY n
}
5: begin
  if loop_p^.looptype = escr_looptype_unc_k then begin {loop type not set yet ?}
    loop_p^.looptype := escr_looptype_cnt_k; {is now a counted loop}
    loop_p^.cnt_const_p := nil;
    end;
  if loop_p^.looptype <> escr_looptype_cnt_k {wrong loop type for this keyword ?}
    then goto err_keyw;
  if keyw_by_k in keyw                 {this keyword already used before ?}
    then goto err_keyw;
  keyw := keyw + [keyw_by_k];          {record that this keyword used}

  if not escr_get_int (e, loop_p^.cnt_inc, stat) {get N}
    then goto err_missing;
  if sys_error(stat) then goto err_abort;
  if loop_p^.cnt_inc = 0 then begin    {invalid iteration increment ?}
    sys_stat_set (escr_subsys_k, escr_err_loopinc0_k, stat);
    goto err_abort;
    end;
  end;
{
******************************
*
*   N n
}
6: begin
  if loop_p^.looptype = escr_looptype_unc_k then begin {loop type not set yet ?}
    loop_p^.looptype := escr_looptype_cnt_k; {is now a counted loop}
    loop_p^.cnt_const_p := nil;
    end;
  if loop_p^.looptype <> escr_looptype_cnt_k {wrong loop type for this keyword ?}
    then goto err_keyw;
  if keyw_n_k in keyw                  {this keyword already used before ?}
    then goto err_keyw;
  keyw := keyw + [keyw_n_k];           {record that this keyword used}

  if not escr_get_int (e, n_n, stat)   {get N}
    then goto err_missing;
  if sys_error(stat) then goto err_abort;
  loop_p^.cnt_inf := false;            {this loop has definite end}
  end;
{
******************************
*
*   Unrecognized keyword.  The upper case keyword is in TK.
}
otherwise
      sys_stat_set (escr_subsys_k, escr_err_badparm_k, stat);
      sys_stat_parm_vstr (tk, stat);
      sys_stat_parm_vstr (e.cmd, stat);
      goto err_abort;
      end;                             {end of keyword cases}
    end;                               {back to get next keyword}

  case loop_p^.looptype of             {what type of loop is this ?}
{
*   Post-keyword processing for unconditional loop.
}
escr_looptype_unc_k: begin
  end;
{
*   Post-keyword processing for symbols loop.
}
escr_looptype_sym_k: begin
  end;
{
*   Post-keyword processing for counted loop.
}
escr_looptype_cnt_k: begin
  if not (keyw_from_k in keyw) then begin
    loop_p^.cnt_start := 1;            {default starting value}
    end;

  if not (keyw_by_k in keyw) then begin {increment not explicitly set ?}
    loop_p^.cnt_inc := 1;
    end;

  if keyw_n_k in keyw then begin       {number of iterations explicitly set ?}
    if
        (keyw_from_k in keyw) and      {start explicitly set ?}
        (keyw_to_k in keyw)            {end explicitly set ?}
        then begin
      sys_stat_set (escr_subsys_k, escr_err_loop_n_k, stat);
      goto err_abort;
      end;
    if n_n <= 0 then begin             {zero iterations, don't run the loop ?}
      e.inhibit_p^.inh := true;        {inhibit execution for this block}
      return;
      end;
    if not (keyw_to_k in keyw)
      then begin                       {make end from start and number}
        loop_p^.cnt_end :=
          loop_p^.cnt_start + (n_n - 1) * loop_p^.cnt_inc;
        end
      else begin                       {make start from end and number}
        loop_p^.cnt_start :=
          loop_p^.cnt_end - (n_n - 1) * loop_p^.cnt_inc;
        end
      ;
    end;

  loop_p^.cnt_curr := loop_p^.cnt_start; {init value for first iteration}

  if not loop_p^.cnt_inf then begin    {not infinite loop ?}
    if
        (loop_p^.cnt_inc > 0) and      {counting up ?}
        (loop_p^.cnt_curr > loop_p^.cnt_end) {already past the end ?}
        then begin
      e.inhibit_p^.inh := true;        {inhibit execution for this block}
      end;
    if
        (loop_p^.cnt_inc < 0) and      {counting down ?}
        (loop_p^.cnt_curr < loop_p^.cnt_end) {already past the end ?}
        then begin
      e.inhibit_p^.inh := true;        {inhibit execution for this block}
      end;
    if e.inhibit_p^.inh then return;   {execution is inhibited ?}
    end;

  if loop_p^.cnt_const_p <> nil then begin {there is a iteration constant ?}
    loop_p^.cnt_const_p^.const_val.int := loop_p^.cnt_curr; {init to value for first iteration}
    end;
  end;                                 {end of counted loop case}

    end;                               {end of looptype cases for post-keyword processing}
  return;
{
*   Error return points.
}
err_missing:                           {missing required parameter}
  escr_stat_cmd_noarg (e, stat);
  goto err_abort;

err_keyw:                              {keyword in TK incompatible with previous keyw}
  sys_stat_set (escr_subsys_k, escr_err_loop_keyw_k, stat);
  sys_stat_parm_vstr (tk, stat);

err_abort:                             {abort with exblock created, STAT all set}
  escr_exblock_close (e, stat2);       {remove the loop execution block created above}
  end;
{
********************************************************************************
*
*   Function LOOP_ITER
*
*   Advance the loop state to the next iteration.  If the terminating condition
*   is met, then the function returns FALSE and the execution location is not
*   altered.  If the terminating condition is not met, then the execution point
*   is set to the first line within the current execution block.
}
function escr_loop_iter (              {advance to next loop iteration}
  in out  e: escr_t;                   {state for this use of the ESCR system}
  out     stat: sys_err_t)             {completion status}
  :boolean;                            {looped back, not terminated}
  val_param;

var
  loop_p: escr_loop_p_t;               {pointer to loop descriptor}
  sym_p: escr_sym_p_t;                 {scratch symbol descriptor pointer}

label
  loop;

begin
  escr_loop_iter := false;             {init to loop terminated}

  if e.exblock_p^.bltype <> escr_exblock_loop_k {not in explicit loop block ?}
    then goto loop;                    {loop back unconditionally}
  loop_p := e.exblock_p^.loop_p;       {get pointer to loop descriptor}
  if loop_p = nil then goto loop;      {no loop data ?}
  case loop_p^.looptype of             {what kind of loop is this ?}
{
******************************
*
*   Unconditional loop.  There is no loop state to advance and no terminating
*   condition to check.
}
escr_looptype_unc_k: ;
{
******************************
*
*   Looping thru a previously saved list of symbol names.
}
escr_looptype_sym_k: begin             {looping thru list of symbols}
  while true do begin
    string_list_pos_rel (loop_p^.sym_list_p^, 1); {advance to next symbols list entry}
    if loop_p^.sym_list_p^.str_p = nil {hit end of list ?}
      then return;

    escr_sym_find (                    {try to find the symbol}
      e, loop_p^.sym_list_p^.str_p^, sym_p);
    if sym_p = nil then next;          {this symbol got deleted, skip it}

    string_copy (                      {copy new name into loop variable}
      loop_p^.sym_list_p^.str_p^, loop_p^.sym_const_p^.const_val.str);
    exit;                              {successfully found next symbol name}
    end;
  end;
{
******************************
*
*   Counted loop.
}
escr_looptype_cnt_k: begin
  loop_p^.cnt_curr :=                  {advance loop value to next iteration}
    loop_p^.cnt_curr + loop_p^.cnt_inc;
  if loop_p^.cnt_const_p <> nil then begin {there is a iteration value constant ?}
    loop_p^.cnt_const_p^.const_val.int := loop_p^.cnt_curr; {update variable for this iteration}
    end;

  if loop_p^.cnt_inf then goto loop;   {infinite loop, no terminating condition ?}

  if                                   {done counting up ?}
      (loop_p^.cnt_end >= loop_p^.cnt_start) and {counting up ?}
      (loop_p^.cnt_curr > loop_p^.cnt_end) {this iteration would be past end ?}
    then return;                       {terminate the loop}
  if                                   {done counting down ?}
      (loop_p^.cnt_end < loop_p^.cnt_start) and {counting up ?}
      (loop_p^.cnt_curr < loop_p^.cnt_end) {this iteration would be past end ?}
    then return;                       {terminate the loop}
  end;
{
******************************
}
otherwise                              {unimplemented loop type}
    writeln ('INTERNAL ERROR: Unexpected loop type encountered in LOOP_ITER.');
    escr_err_atline (e, '', '', nil, 0);
    end;                               {end of loop type cases}

loop:                                  {loop execution back to start of block}
  escr_exblock_repeat (e, stat);       {jump back to start of block}
  if sys_error(stat) then return;
  escr_loop_iter := true;              {indicate execution was looped back}
  end;
{
********************************************************************************
*
*   Subroutine  ESCR_CMD_ENDLOOP (E, STAT)
}
procedure escr_cmd_endloop (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param;

label
  del_block;

begin
  sys_error_none (stat);               {init to no error occurred}

  if e.exblock_p^.bltype <> escr_exblock_loop_k then begin {not in LOOP block type ?}
    sys_stat_set (escr_subsys_k, escr_err_notloop_k, stat);
    return;
    end;
  if e.exblock_p^.inpos_p^.prev_p <> nil then begin {block ended in include file ?}
    sys_stat_set (escr_subsys_k, escr_err_endblock_include_k, stat);
    sys_stat_parm_vstr (e.cmd, stat);
    return;
    end;
  if e.inhibit_p^.inh then goto del_block; {execution is inhibited ?}

  if not escr_get_end (e, stat) then return; {abort on extra parameter}
  if escr_loop_iter(e, stat) then return; {back to do next loop iteration ?}
  if sys_error(stat) then return;

del_block:                             {delete this block}
  e.exblock_p^.prev_p^.inpos_p^.line_p := {restart previous block after this command}
    e.exblock_p^.inpos_p^.line_p;
  escr_exblock_close (e, stat);        {end this execution block}
  end;
