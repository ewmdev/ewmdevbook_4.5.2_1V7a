class ZCL_IM__TU_COPY definition
  public
  final
  create public .

public section.

  interfaces IF_EX_EXEC_METHODCALL_PPF .
protected section.
private section.
ENDCLASS.



CLASS ZCL_IM__TU_COPY IMPLEMENTATION.


  METHOD if_ex_exec_methodcall_ppf~execute.

    DATA: lt_tu_key TYPE /scwm/tt_aspk_tu.

    BREAK-POINT ID zewmdevbook_1v7a.

    rp_status = sppf_status_error.
    "1) Cast imported PPFf-object to get the TU-key:
    DATA(lo_tu_ppf) = CAST /scwm/cl_sr_tu_ppf( io_appl_object ).
    DATA(ls_key) = VALUE /scwm/s_tu_sr_act_num(
      tu_num        = lo_tu_ppf->get_tu_num( )
      tu_sr_act_num = lo_tu_ppf->get_tu_sr_act_num( ) ).
    IF ( ls_key-tu_num IS INITIAL ) OR ( ls_key-tu_sr_act_num IS INITIAL ).
      MESSAGE e136(/scwm/shp_rcv) WITH flt_val INTO DATA(msg).
      CALL METHOD cl_log_ppf=>add_message
        EXPORTING
          ip_problemclass = wmegc_log_vip "'1' very important
          ip_handle       = ip_application_log.
      EXIT.
    ENDIF.
    TRY.
        "2) Get the bo for the inbound TU
        DATA(lo_bom) = /scwm/cl_sr_bom=>get_instance( ).
        DATA(lo_tu)  = lo_bom->get_bo_tu_by_key(
          EXPORTING
            is_tu_sr_act_num = ls_key ).
        "3) Get active door of the inb TU
        lo_tu->get_tu_door(
          EXPORTING
            iv_get_executed = space
          IMPORTING
            et_bo_tu_door   = DATA(lt_door) ).
        LOOP AT lt_door ASSIGNING FIELD-SYMBOL(<ls_door>)
        WHERE start_actual IS NOT INITIAL
        AND end_actual IS INITIAL.
          EXIT. "active door found
        ENDLOOP.
        IF <ls_door> IS NOT ASSIGNED.
          RETURN.
        ENDIF.
        lo_tu->get_data(
          IMPORTING
            es_act = DATA(ls_act) ).
        "4) Create a new outbound TU (copy from inbound)
        DATA(ls_tu_new) = CORRESPONDING /scwm/s_bo_tu_new( <ls_door> ). "times
        ls_tu_new-yard = <ls_door>-lgnum.
        ls_tu_new-act_dir = /scdl/if_dl_doc_c=>sc_procat_out.
        lo_bom->create_new_bo_tu(
          EXPORTING
            is_bo_tu_new     = ls_tu_new
            is_tu_sr_act_num = ls_key
          IMPORTING
            eo_bo_tu         = DATA(lo_tu_new) ).
        ls_key = lo_tu_new->get_num( ).
        /scwm/cl_tm=>set_lgnum( iv_lgnum = ls_act-yard ).
        "5) Activate the outbound TU
        APPEND ls_key TO lt_tu_key.
        /scwm/cl_sr_my_service=>switch_tu_active(
          EXPORTING
            iv_lgnum   = ls_act-yard
            it_aspk_tu = lt_tu_key ).
        "6) Save
        lo_bom->save( ).
      CATCH /scwm/cx_sr_error .
        CALL METHOD cl_log_ppf=>add_message
          EXPORTING
            ip_problemclass = wmegc_log_vip "'1' very important
            ip_handle       = ip_application_log.
        /scwm/cl_tm=>cleanup( ).
        EXIT.
    ENDTRY.
    /scwm/cl_tm=>cleanup( ).
    rp_status = sppf_status_processed.

  ENDMETHOD.
ENDCLASS.
