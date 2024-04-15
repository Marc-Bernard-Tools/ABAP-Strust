CLASS zcl_strust2 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

************************************************************************
* Trust Management
*
* Copyright 2021 Marc Bernard <https://marcbernardtools.com/>
* SPDX-License-Identifier: MIT
************************************************************************
  PUBLIC SECTION.

    CONSTANTS c_version TYPE string VALUE '1.1.0' ##NEEDED.

    TYPES:
      ty_line        TYPE c LENGTH 80,
      ty_certificate TYPE STANDARD TABLE OF ty_line WITH DEFAULT KEY,
      BEGIN OF ty_certattr,
        subject     TYPE string,
        issuer      TYPE string,
        serialno    TYPE string,
        validfrom   TYPE string,
        validto     TYPE string,
        datefrom    TYPE d,
        dateto      TYPE d,
        certificate TYPE xstring,
      END OF ty_certattr,
      ty_certattr_tt TYPE STANDARD TABLE OF ty_certattr WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING
        !iv_context TYPE psecontext
        !iv_applic  TYPE ssfappl
      RAISING
        zcx_strust2.

    METHODS load
      IMPORTING
        !iv_create TYPE abap_bool DEFAULT abap_false
        !iv_id     TYPE ssfid OPTIONAL
        !iv_org    TYPE string OPTIONAL
      RAISING
        zcx_strust2.

    METHODS add
      IMPORTING
        !it_certificate TYPE ty_certificate
      RAISING
        zcx_strust2.

    METHODS get_own_certificate
      RETURNING
        VALUE(rs_result) TYPE ty_certattr
      RAISING
        zcx_strust2.

    METHODS get_certificate_list
      RETURNING
        VALUE(rt_result) TYPE ty_certattr_tt
      RAISING
        zcx_strust2.

    METHODS remove
      IMPORTING
        VALUE(iv_subject) TYPE string
      RAISING
        zcx_strust2.

    METHODS update
      RETURNING
        VALUE(rt_result) TYPE ty_certattr_tt
      RAISING
        zcx_strust2.

  PROTECTED SECTION.
  PRIVATE SECTION.

    DATA:
      mv_context   TYPE psecontext,
      mv_applic    TYPE ssfappl,
      mv_psename   TYPE ssfpsename,
      mv_psetext   TYPE strustappltxt ##NEEDED,
      mv_distrib   TYPE ssfflag,
      mv_tempfile  TYPE localfile,
      mv_id        TYPE ssfid,
      mv_profile   TYPE ssfpab,
      mv_profilepw TYPE ssfpabpw,
      mv_cert_own  TYPE xstring,
      mt_cert_new  TYPE ty_certattr_tt,
      ms_cert_old  TYPE ty_certattr,
      mt_cert_old  TYPE ty_certattr_tt,
      mv_save      TYPE abap_bool.

    METHODS _create
      IMPORTING
        !iv_id  TYPE ssfid OPTIONAL
        !iv_org TYPE string OPTIONAL
      RAISING
        zcx_strust2.

    METHODS _lock
      RAISING
        zcx_strust2.

    METHODS _unlock
      RAISING
        zcx_strust2.

    METHODS _save
      RAISING
        zcx_strust2.

ENDCLASS.



CLASS zcl_strust2 IMPLEMENTATION.


  METHOD add.

    DATA:
      lv_certb64  TYPE string,
      lo_certobj  TYPE REF TO cl_abap_x509_certificate,
      ls_cert_new TYPE ty_certattr.

    FIELD-SYMBOLS:
      <lv_data> TYPE any.

    CONCATENATE LINES OF it_certificate INTO lv_certb64.

    " Remove Header and Footer
    TRY.
        FIND REGEX '-{5}.{0,}BEGIN.{0,}-{5}(.*)-{5}.{0,}END.{0,}-{5}' IN lv_certb64 SUBMATCHES lv_certb64.
        IF sy-subrc = 0.
          ASSIGN lv_certb64 TO <lv_data>.
          ASSERT sy-subrc = 0.
        ELSE.
          zcx_strust2=>raise( 'Inconsistent certificate format'(010) ).
        ENDIF.
      CATCH cx_sy_regex_too_complex.
        " e.g. multiple PEM frames in file
        zcx_strust2=>raise( 'Inconsistent certificate format'(010) ).
    ENDTRY.

    TRY.
        CREATE OBJECT lo_certobj
          EXPORTING
            if_certificate = <lv_data>.

        ls_cert_new-certificate = lo_certobj->get_certificate( ).

        CALL FUNCTION 'SSFC_PARSE_CERTIFICATE'
          EXPORTING
            certificate         = ls_cert_new-certificate
          IMPORTING
            subject             = ls_cert_new-subject
            issuer              = ls_cert_new-issuer
            serialno            = ls_cert_new-serialno
            validfrom           = ls_cert_new-validfrom
            validto             = ls_cert_new-validto
          EXCEPTIONS
            ssf_krn_error       = 1
            ssf_krn_nomemory    = 2
            ssf_krn_nossflib    = 3
            ssf_krn_invalid_par = 4
            OTHERS              = 5.
        IF sy-subrc <> 0.
          _unlock( ).
          zcx_strust2=>raise_t100( ).
        ENDIF.

        ls_cert_new-datefrom = ls_cert_new-validfrom(8).
        ls_cert_new-dateto   = ls_cert_new-validto(8).
        APPEND ls_cert_new TO mt_cert_new.

      CATCH cx_abap_x509_certificate.
        _unlock( ).
        zcx_strust2=>raise_t100( ).
    ENDTRY.

  ENDMETHOD.


  METHOD constructor.

    mv_context = iv_context.
    mv_applic  = iv_applic.

    CALL FUNCTION 'SSFPSE_FILENAME'
      EXPORTING
        context       = mv_context
        applic        = mv_applic
      IMPORTING
        psename       = mv_psename
        psetext       = mv_psetext
        distrib       = mv_distrib
      EXCEPTIONS
        pse_not_found = 1
        OTHERS        = 2.
    IF sy-subrc <> 0.
      zcx_strust2=>raise_t100( ).
    ENDIF.

  ENDMETHOD.


  METHOD get_certificate_list.

    DATA:
      lt_certlist TYPE ssfbintab,
      ls_cert_old TYPE ty_certattr.

    FIELD-SYMBOLS <lv_certlist> LIKE LINE OF lt_certlist.

    CALL FUNCTION 'SSFC_GET_CERTIFICATELIST'
      EXPORTING
        profile               = mv_profile
        profilepw             = mv_profilepw
      IMPORTING
        certificatelist       = lt_certlist
      EXCEPTIONS
        ssf_krn_error         = 1
        ssf_krn_nomemory      = 2
        ssf_krn_nossflib      = 3
        ssf_krn_invalid_par   = 4
        ssf_krn_nocertificate = 5
        OTHERS                = 6.
    IF sy-subrc <> 0.
      _unlock( ).
      zcx_strust2=>raise_t100( ).
    ENDIF.

    LOOP AT lt_certlist ASSIGNING <lv_certlist>.

      CLEAR ls_cert_old.

      CALL FUNCTION 'SSFC_PARSE_CERTIFICATE'
        EXPORTING
          certificate         = <lv_certlist>
        IMPORTING
          subject             = ls_cert_old-subject
          issuer              = ls_cert_old-issuer
          serialno            = ls_cert_old-serialno
          validfrom           = ls_cert_old-validfrom
          validto             = ls_cert_old-validto
        EXCEPTIONS
          ssf_krn_error       = 1
          ssf_krn_nomemory    = 2
          ssf_krn_nossflib    = 3
          ssf_krn_invalid_par = 4
          OTHERS              = 5.
      IF sy-subrc <> 0.
        _unlock( ).
        zcx_strust2=>raise_t100( ).
      ENDIF.

      ls_cert_old-datefrom = ls_cert_old-validfrom(8).
      ls_cert_old-dateto   = ls_cert_old-validto(8).
      APPEND ls_cert_old TO mt_cert_old.

    ENDLOOP.

    rt_result = mt_cert_old.

  ENDMETHOD.


  METHOD get_own_certificate.

    mv_profile = mv_tempfile.

    CALL FUNCTION 'SSFC_GET_OWNCERTIFICATE'
      EXPORTING
        profile               = mv_profile
        profilepw             = mv_profilepw
      IMPORTING
        certificate           = mv_cert_own
      EXCEPTIONS
        ssf_krn_error         = 1
        ssf_krn_nomemory      = 2
        ssf_krn_nossflib      = 3
        ssf_krn_invalid_par   = 4
        ssf_krn_nocertificate = 5
        OTHERS                = 6.
    IF sy-subrc <> 0.
      _unlock( ).
      zcx_strust2=>raise_t100( ).
    ENDIF.

    CALL FUNCTION 'SSFC_PARSE_CERTIFICATE'
      EXPORTING
        certificate         = mv_cert_own
      IMPORTING
        subject             = ms_cert_old-subject
        issuer              = ms_cert_old-issuer
        serialno            = ms_cert_old-serialno
        validfrom           = ms_cert_old-validfrom
        validto             = ms_cert_old-validto
      EXCEPTIONS
        ssf_krn_error       = 1
        ssf_krn_nomemory    = 2
        ssf_krn_nossflib    = 3
        ssf_krn_invalid_par = 4
        OTHERS              = 5.
    IF sy-subrc <> 0.
      _unlock( ).
      zcx_strust2=>raise_t100( ).
    ENDIF.

    ms_cert_old-datefrom = ms_cert_old-validfrom(8).
    ms_cert_old-dateto   = ms_cert_old-validto(8).

    rs_result = ms_cert_old.

  ENDMETHOD.


  METHOD load.

    CLEAR mv_save.

    _lock( ).

    CALL FUNCTION 'SSFPSE_LOAD'
      EXPORTING
        psename           = mv_psename
      IMPORTING
        id                = mv_id
        fname             = mv_tempfile
      EXCEPTIONS
        authority_missing = 1
        database_failed   = 2
        OTHERS            = 3.
    IF sy-subrc <> 0.
      IF iv_create = abap_true.
        _create(
          iv_id  = iv_id
          iv_org = iv_org ).
      ELSE.
        zcx_strust2=>raise_t100( ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD remove.

    FIELD-SYMBOLS:
      <ls_cert_old> LIKE LINE OF mt_cert_old.

    " Remove certificate
    LOOP AT mt_cert_old ASSIGNING <ls_cert_old> WHERE subject = iv_subject.

      CALL FUNCTION 'SSFC_REMOVECERTIFICATE'
        EXPORTING
          profile               = mv_profile
          profilepw             = mv_profilepw
          subject               = <ls_cert_old>-subject
          issuer                = <ls_cert_old>-issuer
          serialno              = <ls_cert_old>-serialno
        EXCEPTIONS
          ssf_krn_error         = 1
          ssf_krn_nomemory      = 2
          ssf_krn_nossflib      = 3
          ssf_krn_invalid_par   = 4
          ssf_krn_nocertificate = 5
          OTHERS                = 6.
      IF sy-subrc <> 0.
        _unlock( ).
        zcx_strust2=>raise_t100( ).
      ENDIF.

      mv_save = abap_true.
    ENDLOOP.

    _save( ).

    _unlock( ).

  ENDMETHOD.


  METHOD update.

    FIELD-SYMBOLS:
      <ls_cert_old> LIKE LINE OF mt_cert_old,
      <ls_cert_new> LIKE LINE OF mt_cert_new.

    " Remove expired certificates
    LOOP AT mt_cert_old ASSIGNING <ls_cert_old>.

      LOOP AT mt_cert_new ASSIGNING <ls_cert_new> WHERE subject = <ls_cert_old>-subject.

        IF <ls_cert_new>-dateto > <ls_cert_old>-dateto.
          " Certificate is newer, so remove the old certificate
          CALL FUNCTION 'SSFC_REMOVECERTIFICATE'
            EXPORTING
              profile               = mv_profile
              profilepw             = mv_profilepw
              subject               = <ls_cert_old>-subject
              issuer                = <ls_cert_old>-issuer
              serialno              = <ls_cert_old>-serialno
            EXCEPTIONS
              ssf_krn_error         = 1
              ssf_krn_nomemory      = 2
              ssf_krn_nossflib      = 3
              ssf_krn_invalid_par   = 4
              ssf_krn_nocertificate = 5
              OTHERS                = 6.
          IF sy-subrc <> 0.
            _unlock( ).
            zcx_strust2=>raise_t100( ).
          ENDIF.

          mv_save = abap_true.
        ELSE.
          " Certificate already exists, no update necessary
          DELETE mt_cert_new.
        ENDIF.

      ENDLOOP.

    ENDLOOP.

    " Add new certificates to PSE
    LOOP AT mt_cert_new ASSIGNING <ls_cert_new>.

      CALL FUNCTION 'SSFC_PUT_CERTIFICATE'
        EXPORTING
          profile             = mv_profile
          profilepw           = mv_profilepw
          certificate         = <ls_cert_new>-certificate
        EXCEPTIONS
          ssf_krn_error       = 1
          ssf_krn_nomemory    = 2
          ssf_krn_nossflib    = 3
          ssf_krn_invalid_par = 4
          ssf_krn_certexists  = 5
          OTHERS              = 6.
      IF sy-subrc <> 0.
        _unlock( ).
        zcx_strust2=>raise_t100( ).
      ENDIF.

      mv_save = abap_true.
    ENDLOOP.

    _save( ).

    _unlock( ).

    rt_result = mt_cert_new.

  ENDMETHOD.


  METHOD _create.

    DATA:
      lv_license_num TYPE c LENGTH 10,
      lv_id          TYPE ssfid,
      lv_subject     TYPE certsubjct,
      lv_psepath     TYPE trfile.

*   Create new PSE (using RSA-SHA256 2048 which is the default in STRUST in recent releases)
    IF iv_id IS INITIAL.
      CASE mv_applic.
        WHEN 'DFAULT'.
          lv_id = `CN=%SID SSL client SSL Client (Standard), ` &&
                  `OU=I%LIC, OU=SAP Web AS, O=SAP Trust Community, C=DE` ##NO_TEXT.
        WHEN 'ANONYM'.
          lv_id = 'CN=anonymous' ##NO_TEXT.
      ENDCASE.
    ELSE.
      lv_id = iv_id.
    ENDIF.

    CALL FUNCTION 'SLIC_GET_LICENCE_NUMBER'
      IMPORTING
        license_number = lv_license_num.

    REPLACE '%SID' WITH sy-sysid INTO lv_id.
    REPLACE '%LIC' WITH lv_license_num INTO lv_id.
    REPLACE '%ORG' WITH iv_org INTO lv_id.
    CONDENSE lv_id.

    lv_subject = lv_id.

    CALL FUNCTION 'SSFPSE_CREATE'
      EXPORTING
        dn                = lv_subject
        alg               = 'R'
        keylen            = 2048
      IMPORTING
        psepath           = lv_psepath
      EXCEPTIONS
        ssf_unknown_error = 1
        OTHERS            = 2.
    IF sy-subrc <> 0.
      zcx_strust2=>raise_t100( ).
    ENDIF.

    mv_tempfile = lv_psepath.

    _save( ).

  ENDMETHOD.


  METHOD _lock.

    CALL FUNCTION 'SSFPSE_ENQUEUE'
      EXPORTING
        psename         = mv_psename
      EXCEPTIONS
        database_failed = 1
        foreign_lock    = 2
        internal_error  = 3
        OTHERS          = 4.
    IF sy-subrc <> 0.
      zcx_strust2=>raise_t100( ).
    ENDIF.

  ENDMETHOD.


  METHOD _save.

    DATA lv_credname TYPE icm_credname.

    CHECK mv_save = abap_true.

    " Store PSE
    CALL FUNCTION 'SSFPSE_STORE'
      EXPORTING
        fname             = mv_tempfile
        psepin            = mv_profilepw
        psename           = mv_psename
        id                = mv_id
        b_newdn           = abap_false
        b_distribute      = mv_distrib
      EXCEPTIONS
        file_load_failed  = 1
        storing_failed    = 2
        authority_missing = 3
        OTHERS            = 4.
    IF sy-subrc <> 0.
      _unlock( ).
      zcx_strust2=>raise_t100( ).
    ENDIF.

    lv_credname = mv_psename.

    CALL FUNCTION 'ICM_SSL_PSE_CHANGED'
      EXPORTING
        global              = 1
        cred_name           = lv_credname
      EXCEPTIONS
        icm_op_failed       = 1
        icm_get_serv_failed = 2
        icm_auth_failed     = 3
        OTHERS              = 4.
    IF sy-subrc = 0.
      MESSAGE s086(trust).
    ELSE.
      MESSAGE s085(trust).
    ENDIF.

  ENDMETHOD.


  METHOD _unlock.

    " Drop temporary file
    TRY.
        DELETE DATASET mv_tempfile.
      CATCH cx_sy_file_open.
        zcx_strust2=>raise( 'Error deleting file'(020) && | { mv_tempfile }| ).
      CATCH cx_sy_file_authority.
        zcx_strust2=>raise( 'Not authorized to delete file'(030) && | { mv_tempfile }| ).
    ENDTRY.

    " Unlock PSE
    CALL FUNCTION 'SSFPSE_DEQUEUE'
      EXPORTING
        psename         = mv_psename
      EXCEPTIONS
        database_failed = 1
        foreign_lock    = 2
        internal_error  = 3
        OTHERS          = 4.
    IF sy-subrc <> 0.
      zcx_strust2=>raise_t100( ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
