{   Error handling.
}
module escr_err;
define escr_err_atline;
define escr_err_atline_abort;
define escr_err_val;
define escr_err_parm_bad;
define escr_err_parm_last_bad;
define escr_err_dtype_unimp;
define escr_err_sym_not_found;
%include 'escr2.ins.pas';
{
****************************************************************************
*
*   Subroutine ESCR_ERR_ATLINE (E, SUBSYS, MSG, PARMS, N_PARMS)
*
*   Write the message from the call parameters, then write a message indicating
*   the current source file name and line number, then exit the program with
*   error status.
}
procedure escr_err_atline (            {show error followed by source line number}
  in out  e: escr_t;                   {state for this use of the ESCR system}
  in      subsys: string;              {name of subsystem, used to find message file}
  in      msg: string;                 {message name withing subsystem file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  options (val_param, noreturn);

const
  max_msg_parms = 2;                   {max parameters we can pass to a message}

var
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;
  block_p: escr_exblock_p_t;           {pointer to nested execution block state}
  inpos_p: escr_inpos_p_t;             {pointer to nested input position state}
  line_p: escr_inline_p_t;             {pointer to definition of one input stream line}

begin
  escr_out_close_all (e, true);        {close and delete all output files}

  sys_message_parms (subsys, msg, parms, n_parms); {write caller's message}

  block_p := e.exblock_p;              {get pointer to current execution block}
  if block_p = nil then return;        {not in a execution block, nothing to report ?}
  inpos_p := block_p^.inpos_p;         {get pointer to nested input file state}
  line_p := inpos_p^.last_p;           {get pointer to current input line info}
  sys_msg_parm_vstr (msg_parm[1], line_p^.file_p^.tnam); {input file name}
  sys_msg_parm_int (msg_parm[2], line_p^.lnum); {input file line number}
  sys_message_parms ('escr', 'err_fnam_lnum', msg_parm, 2);

  inpos_p := inpos_p^.prev_p;          {back to next nested input file this execution block}
  while block_p <> nil do begin        {back thru the nested execution blocks}
    while inpos_p <> nil do begin      {back thru nested input files this execution block}
      line_p := inpos_p^.last_p;       {get pointer to last read line}
      sys_msg_parm_vstr (msg_parm[1], line_p^.file_p^.tnam); {file name}
      sys_msg_parm_int (msg_parm[2], line_p^.lnum); {line number}
      sys_message_parms ('escr', 'included_from', msg_parm, 2);
      inpos_p := inpos_p^.prev_p;      {back to file included from}
      end;
    if block_p^.prev_p <> nil then begin {in a nested execution block ?}
      sys_msg_parm_int (msg_parm[1], block_p^.start_p^.lnum); {block start line number}
      sys_msg_parm_vstr (msg_parm[2], block_p^.start_p^.file_p^.tnam); {block start fname}
      sys_message_parms ('escr', 'in_block', msg_parm, 2);
      end;
    block_p := block_p^.prev_p;        {one level up to parent execution block}
    end;

  sys_bomb;                            {exit the program with error status}
  end;
{
****************************************************************************
*
*   Subroutine ESCR_ERR_ATLINE_ABORT (E, STAT, SUBSYS, MSG, PARMS, N_PARMS)
*
*   If STAT is indicating an error, then write the error and identify the
*   current source line, then bomb the program.  Nothing is done if
*   STAT is not indicating an error.
}
procedure escr_err_atline_abort (      {bomb with msg and source line on error}
  in out  e: escr_t;                   {state for this use of the ESCR system}
  in      stat: sys_err_t;             {error code, nothing done if no error}
  in      subsys: string;              {subsystem name of caller's message}
  in      msg: string;                 {name of caller's message within subsystem}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  val_param;

begin
  if not sys_error(stat) then return;  {STAT is not indicating an error ?}

  sys_error_print (stat, subsys, msg, parms, n_parms); {write caller's error msg}
  escr_err_atline (e, '', '', nil, 0); {indicate source line and bomb}
  end;
{
****************************************************************************
*
*   Subroutine ESCR_ERR_VAL (E, VAL)
*
*   Show the data type and value of VAL.
}
procedure escr_err_val (               {show value and data type of offending value}
  in out  e: escr_t;                   {state for this use of the ESCR system}
  in      val: escr_val_t);            {the value}
  val_param;

const
  max_msg_parms = 1;                   {max parameters we can pass to a message}

var
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;

begin
  case val.dtype of                    {what is the value's data type ?}
escr_dtype_bool_k: begin               {boolean}
      if val.bool
        then sys_msg_parm_str (msg_parm[1], 'TRUE')
        else sys_msg_parm_str (msg_parm[1], 'FALSE');
      sys_message_parms ('escr', 'term_val_bool', msg_parm, 1);
      end;
escr_dtype_int_k: begin                {integer}
      sys_msg_parm_int (msg_parm[1], val.int);
      sys_message_parms ('escr', 'term_val_int', msg_parm, 1);
      end;
escr_dtype_fp_k: begin                 {floating point}
      sys_msg_parm_fp2 (msg_parm[1], val.fp);
      sys_message_parms ('escr', 'term_val_fp', msg_parm, 1);
      end;
escr_dtype_str_k: begin                {string}
      sys_msg_parm_vstr (msg_parm[1], val.str);
      sys_message_parms ('escr', 'term_val_str', msg_parm, 1);
      end;
otherwise
    sys_msg_parm_int (msg_parm[1], ord(val.dtype));
    sys_message_parms ('escr', 'term_val_unk', msg_parm, 1);
    end;
  end;
{
****************************************************************************
*
*   Subroutine ESCR_ERR_PARM_BAD (E, PARM)
*
*   Bomb program with error message about the bad parameter PARM to the
*   current command.  The source file and line number will be shown.
}
procedure escr_err_parm_bad (          {bomb with bad parameter to command error}
  in out  e: escr_t;                   {state for this use of the ESCR system}
  in      parm: univ string_var_arg_t); {the offending parameter}
  options (val_param, noreturn);

const
  max_msg_parms = 2;                   {max parameters we can pass to a message}

var
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;

begin
  sys_msg_parm_vstr (msg_parm[1], parm);
  sys_msg_parm_vstr (msg_parm[2], e.cmd);
  escr_err_atline (e, 'escr', 'parm_bad_cmd', msg_parm, 2);
  end;
{
****************************************************************************
*
*   Subroutine ESCR_ERR_PARM_LAST_BAD (E)
*
*   Like ERR_PARM_BAD except that it automatically works on the last
*   parameter parsed from the input line.
}
procedure escr_err_parm_last_bad (     {last parameter parsed was bad}
  in out  e: escr_t);                  {state for this use of the ESCR system}
  options (val_param, noreturn);

begin
  escr_err_parm_bad (e, e.lparm);
  end;
{
****************************************************************************
*
*   Subroutine ESCR_ERR_DTYPE_UNIMP (E, DTYPE, ROUTINE)
*
*   Indicate an internal error has occurred where data type DTYPE is not supported
*   in routine ROUTINE.  The program will be aborted with error.
}
procedure escr_err_dtype_unimp (       {unimplemented data type internal error}
  in out  e: escr_t;                   {state for this use of the ESCR system}
  in      dtype: escr_dtype_k_t;       {unimplemented data type}
  in      routine: string);            {name of the routine where data type unimplemented}
  options (val_param, noreturn);

const
  max_msg_parms = 2;                   {max parameters we can pass to a message}

var
  msg_parm:                            {parameter references for messages}
    array[1..max_msg_parms] of sys_parm_msg_t;

begin
  sys_msg_parm_int (msg_parm[1], ord(dtype));
  sys_msg_parm_str (msg_parm[2], routine);
  escr_err_atline (e, 'escr', 'err_dtype_unimp', msg_parm, 2);
  end;
