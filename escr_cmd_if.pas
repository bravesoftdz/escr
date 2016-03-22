{   IF statement.
}
module prepic_cmd_if;
define prepic_cmd_if;
define prepic_cmd_then;
define prepic_cmd_else;
define prepic_cmd_endif;
%include 'prepic.ins.pas';
{
********************************************************************************
*
*   Subroutine PREPIC_CMD_IF (STAT)
*
*   /IF condition [THEN]
*
*   Execute the following code if the condition is TRUE.  If the THEN keyword
*   is used, then the following code is conditionally executed until the next
*   /ENDIF command.  With THEN used, the total IF structure has the form:
*
*     /IF condition THEN
*       - executed on TRUE -
*       /ENDIF
*
*   If the THEN keyword is omitted, then the IF structure has this form:
*
*     /IF condition
*         - always executed -
*       /THEN
*         - executed on TRUE -
*       /ELSE
*         - executed on FALSE -
*       /ENDIF
}
procedure prepic_cmd_if (
  out     stat: sys_err_t);
  val_param;

var
  pick: sys_int_machine_t;             {number of keyword picked from list}
  cond: boolean;                       {the IF condition value}

begin
  inh_new;                             {create new execution inhibit layer}
  inhibit_p^.inhty := inhty_if_k;      {this inhibit is for IF command}
  if inhibit_p^.inh then return;       {already inhibited, just track IF nesting ?}
  inhibit_p^.if_flags := [];           {init all IF control flags to off}

  if not get_bool (cond) then begin    {get the value of the conditional}
    err_parm_missing ('', '', nil, 0);
    end;
  if cond then begin                   {the IF condition is TRUE}
    inhibit_p^.if_flags := inhibit_p^.if_flags + [ifflag_true_k]; {set flag accordingly}
    inhibit_p^.inh := false;           {execution starts out enabled}
    end;

  inhibit_p^.inh := false;             {init execution enabled following IF}

  get_keyword ('THEN', pick);          {read THEN keyword if present}
  if pick = 1 then begin               {THEN keyword used ?}
    inhibit_p^.inh := not cond;        {enable execution only if condition was true}
    inhibit_p^.if_flags :=             {THEN and command not allowed}
      inhibit_p^.if_flags + [ifflag_nothen_k];
    end;
  get_end;                             {error if anything else on command line}
  end;
{
********************************************************************************
*
*   Subroutine PREPIC_CMD_THEN (STAT)
}
procedure prepic_cmd_then (
  out     stat: sys_err_t);
  val_param;

begin
  if inhibit_p^.inhty <> inhty_if_k then begin {not in IF structure ?}
    err_atline ('pic', 'not_in_if', nil, 0);
    end;
  get_end;                             {error if anything else on command line}
  if inhibit_p^.prev_p^.inh then return; {whole IF inhibited, just tracking nesting ?}

  if ifflag_nothen_k in inhibit_p^.if_flags then begin {THEN not allowed here ?}
    err_atline ('pic', 'ill_then', nil, 0);
    end;
  inhibit_p^.if_flags :=               {no subsequent THEN command allowed this IF}
    inhibit_p^.if_flags + [ifflag_nothen_k];

  inhibit_p^.inh :=                    {disable execution if condition was FALSE}
    not (ifflag_true_k in inhibit_p^.if_flags);
  end;
{
********************************************************************************
*
*   Subroutine PREPIC_CMD_ELSE (STAT)
}
procedure prepic_cmd_else (
  out     stat: sys_err_t);
  val_param;

begin
  if inhibit_p^.inhty <> inhty_if_k then begin {not in IF structure ?}
    err_atline ('pic', 'not_in_if', nil, 0);
    end;
  get_end;                             {error if anything else on command line}
  if inhibit_p^.prev_p^.inh then return; {whole IF inhibited, just tracking nesting ?}

  if ifflag_noelse_k in inhibit_p^.if_flags then begin {ELSE not allowed here ?}
    err_atline ('pic', 'ill_else', nil, 0);
    end;
  inhibit_p^.if_flags :=               {no subsequent THEN or ELSE command allowed this IF}
    inhibit_p^.if_flags + [ifflag_nothen_k, ifflag_noelse_k];

  inhibit_p^.inh :=                    {disable execution if condition was TRUE}
    ifflag_true_k in inhibit_p^.if_flags;
  end;
{
********************************************************************************
*
*   Subroutine PREPIC_CMD_ENDIF (STAT)
}
procedure prepic_cmd_endif (
  out     stat: sys_err_t);
  val_param;

begin
  if inhibit_p^.inhty <> inhty_if_k then begin {not in IF structure ?}
    err_atline ('pic', 'not_in_if', nil, 0);
    end;

  if                                   {neither THEN nor ELSE encountered ?}
      (not inhibit_p^.prev_p^.inh) and {whole IF command not inhibited ?}
      (not (ifflag_nothen_k in inhibit_p^.if_flags)) and {no THEN ?}
      (not (ifflag_noelse_k in inhibit_p^.if_flags)) {no ELSE ?}
      then begin
    err_atline ('pic', 'err_if_nothenelse', nil, 0);
    end;

  inh_end;                             {remove the execution inhibit for the IF structure}
  get_end;                             {error if anything else on command line}
  end;
