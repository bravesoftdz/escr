{   Subroutine management.
}
module escr_cmd_subr;
define escr_cmd_subroutine;
define escr_cmd_endsub;
define escr_cmd_call;
define escr_cmd_return;
%include 'escr2.ins.pas';
{
********************************************************************************
*
*   Subroutine  ESCR_CMD_SUBROUTINE (E, STAT)
*
*   /SUBROUTINE name
*
*   Define the start of a subroutine.  The subroutine definition is stored,
*   but is not executed now.
}
procedure escr_cmd_subroutine (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param;

var
  name: string_var80_t;                {subroutine name}
  sz: sys_int_adr_t;                   {size of new descriptor}
  sym_p: escr_sym_p_t;                 {pointer to new subroutine name symbol}
  stat2: sys_err_t;                    {to avoid corrupting STAT}

label
  error;

begin
  name.max := size_char(name.str);     {init local var string}

  escr_inh_new (e);                    {create new execution inhibit layer}
  e.inhibit_p^.inhty := escr_inhty_blkdef_k; {inhibit it due to reading block definition}
  e.inhibit_p^.blkdef_type := escr_exblock_sub_k; {block type is subroutine}
  if e.inhibit_p^.inh then return;     {previously inhibited, don't define subroutine}
  e.inhibit_p^.inh := true;            {inhibit execution during subroutine definition}

  if not escr_get_token (e, name) then begin {get subroutine name}
    escr_stat_cmd_noarg (e, stat);
    goto error;
    end;

  sz :=                                {make size of whole subroutine symbol}
    offset(escr_sym_t.subr_line_p) + size_min(escr_sym_t.subr_line_p);
  escr_sym_new (                       {create new symbol for subroutine name}
    e, name, sz, false, e.sym_sub, sym_p, stat);
  if sys_error(stat) then goto error;

  sym_p^.stype := escr_sym_subr_k;     {this symbol is a subroutine name}
  sym_p^.subr_line_p :=                {save pointer to subroutine definition line}
    e.exblock_p^.inpos_p^.last_p;
  return;

error:                                 {error after inhibit created, STAT set}
  escr_inh_end (e, stat2);             {delete the execution inhibit}
  end;
{
********************************************************************************
*
*   Subroutine  ESCR_CMD_ENDSUB (E, STAT)
*
*   /ENDSUB
*
*   Indicate the end of a subroutine definition.
}
procedure escr_cmd_endsub (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param;

begin
  if not e.inhibit_p^.inh then begin   {executing code normally ?}
    escr_cmd_return (e, stat);         {acts just like RETURN}
    return;
    end;

  if                                   {not defining a subroutine ?}
      (e.inhibit_p^.inhty <> escr_inhty_blkdef_k) or {not in a block definition ?}
      (e.inhibit_p^.blkdef_type <> escr_exblock_sub_k) {block is not a subroutine ?}
      then begin
    sys_stat_set (escr_subsys_k, escr_err_notsubdef_k, stat);
    return;
    end;

  escr_inh_end (e, stat);              {end excution inhibit due to subroutine def}
  end;
{
********************************************************************************
*
*   Subroutine ESCR_CMD_CALL (E, STAT)
*
*   /CALL name [arg ... arg]
*
*   Execute the indicated subroutine, then return to after this command when the
*   subroutine completes.
}
procedure escr_cmd_call (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param;

var
  name: string_var80_t;                {subroutine name}
  tk: string_var8192_t;                {scratch token}
  sym_p: escr_sym_p_t;                 {pointer to definition symbol}

begin
  if e.inhibit_p^.inh then return;     {execution is inhibited ?}
  name.max := size_char(name.str);     {init local var strings}
  tk.max := size_char(tk.str);

  if not escr_get_token (e, name) then begin {get subroutine name}
    escr_stat_cmd_noarg (e, stat);
    return;
    end;

  escr_sym_find_type (                 {get symbol from subroutine name}
    e, name, escr_sytype_subr_k, sym_p, stat);
  if sys_error(stat) then return;
  if sym_p = nil then begin            {not found ?}
    escr_stat_sym_nfound (name, stat);
    return;
    end;

  escr_exblock_new (e, stat);          {create new execution block}
  if sys_error(stat) then return;
  escr_exblock_refsym (e, sym_p^);     {indicate referencing symbol for this subroutine}
  e.exblock_p^.bltype := escr_exblock_sub_k; {new block is a subroutine}
  e.exblock_p^.args := true;           {this block can take arguments}
  escr_exblock_arg_addn (e, name, 0);  {subroutine name is special argument 0}
  while true do begin                  {loop until argument list exhausted}
    if not escr_get_tkraw (e, tk) then exit; {get next argument}
    escr_exblock_arg_add (e, tk);      {add as next argument to new execution block}
    end;
  escr_exblock_inline_set (            {go to subroutine definition line}
    e, sym_p^.subr_line_p, stat);
  if sys_error(stat) then return;
  escr_infile_skipline (e);            {skip over subroutine definition line}
  escr_exblock_ulab_init (e);          {create table for local labels}
  end;
{
********************************************************************************
*
*   Subroutine  ESCR_CMD_RETURN (E, STAT)
*
*   /RETURN
*
*   Return from the innermost subroutine currently in.
}
procedure escr_cmd_return (
  in out  e: escr_t;
  out     stat: sys_err_t);
  val_param;

begin
  if e.inhibit_p^.inh then return;     {execution is inhibited ?}

  while e.exblock_p <> nil do begin    {up thru the nested blocks}
    case e.exblock_p^.bltype of        {what kind of block is this ?}
escr_exblock_top_k: begin              {at top block}
        sys_stat_set (escr_subsys_k, escr_err_notsub_k, stat);
        return;
        end;
escr_exblock_sub_k: begin              {the block to close}
        escr_exblock_close (e, stat);  {end this subroutine}
        return;
        end;
escr_exblock_blk_k,                    {BLOCK ... ENDBLOCK}
escr_exblock_loop_k: begin             {LOOP ... ENDLOOP}
        escr_exblock_close (e, stat);  {close this block}
        if sys_error(stat) then return;
        end;
otherwise                              {invalid block type for QUITMAC}
      sys_stat_set (escr_subsys_k, escr_err_notsub_k, stat);
      return;
      end;
    end;                               {back to close new current block}
  end;
