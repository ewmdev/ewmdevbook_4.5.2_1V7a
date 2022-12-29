class ZCL_IM__TU_COPY_SCHED definition
  public
  final
  create public .

public section.

  interfaces IF_EX_EVAL_SCHEDCOND_PPF .
protected section.
private section.

  constants C_MTR_ZSWAP type /SCMB/MDL_TTYPE value 'ZSWAP' ##NO_TEXT.
ENDCLASS.



CLASS ZCL_IM__TU_COPY_SCHED IMPLEMENTATION.


  METHOD if_ex_eval_schedcond_ppf~evaluate_schedule_condition.

    BREAK-POINT ID zewmdevbook_1v7a.

    ep_rc = 1. "Condition not fulfilled
    DATA(lo_context) = CAST /scwm/cl_sr_context_tuppf( io_context ).
    IF lo_context->only_sync = abap_true.
      RETURN.
    ENDIF.
    "1) Cast imported PPF-object to get the TU-key:
    DATA(lo_tu_ppf) = CAST /scwm/cl_sr_tu_ppf( io_context->appl ).
    DATA(ls_key) = VALUE /scwm/s_tu_sr_act_num(
      tu_num        = lo_tu_ppf->get_tu_num( )
      tu_sr_act_num = lo_tu_ppf->get_tu_sr_act_num( ) ).
    IF ( ls_key-tu_num IS INITIAL ) OR
    ( ls_key-tu_sr_act_num IS INITIAL ).
      MESSAGE e136(/scwm/shp_rcv) WITH flt_val
      INTO DATA(msg).
      CALL METHOD cl_log_ppf=>add_message
        EXPORTING
          ip_problemclass = wmegc_log_vip "'1' very important
          ip_handle       = ip_protocol.
      EXIT.
    ENDIF.
    IF lo_tu_ppf->get_deleted( ) = abap_true.
      "Undefined side effects may occur.
      EXIT.
    ENDIF.
    TRY.
        "2) Get the bo for the inbound TU
        DATA(lo_bom) = /scwm/cl_sr_bom=>get_instance( ).
        DATA(lo_tu)  = lo_bom->get_bo_tu_by_key(
          EXPORTING
            is_tu_sr_act_num = ls_key ).
        "3) Check direction of the TU
        CALL METHOD lo_tu->get_sr_act_dir
          RECEIVING
            ev_sr_act_dir = DATA(lv_dir).
        IF lv_dir <> wmesr_sr_act_dir_inb .
          EXIT. "no inbound tu
        ENDIF.
        "4) Check the status ”unloading end”
        DATA(lv_status) = wmesr_status_unload_end.
        DATA(lv_tu_status) =
        lo_tu->get_status_by_id( lv_status ) .
        IF lv_tu_status = abap_false.
          EXIT. "not unloaded yet
        ENDIF.
        IF lo_tu->get_status_change_by_id(
        lv_status ) = abap_false.
          EXIT. "not the correct point of time
        ENDIF.
        "5) Check status ”goods receipt” if dlvs are assigned
        lo_tu->get_tu_dlv(
          EXPORTING
            iv_dlv_data_retrieval = abap_true
          IMPORTING
            et_bo_tu_dlv          = DATA(lt_bo_tu_dlv) ).
        IF lt_bo_tu_dlv IS NOT INITIAL.
          CLEAR lv_tu_status.
          lv_status = wmesr_status_goods_receipt.
          lv_tu_status =
          lo_tu->get_status_by_id( lv_status ) .
          IF lv_tu_status = abap_false.
            EXIT. "not unloaded yet
          ENDIF.
        ENDIF.
        "6) Check the means of transport
        DATA(lv_mtr) = lo_tu->get_mtr( ).
        IF lv_mtr = c_mtr_zswap. "'ZSWAP'
          ep_rc = 0.
        ENDIF.
      CATCH /scwm/cx_sr_error .
        CALL METHOD cl_log_ppf=>add_message
          EXPORTING
            ip_problemclass = wmegc_log_vip "'1' very important
            ip_handle       = ip_protocol.
        EXIT.
    ENDTRY.

  ENDMETHOD.
ENDCLASS.
