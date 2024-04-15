![Version](https://img.shields.io/endpoint?url=https://shield.abap.space/version-shield-json/github/Marc-Bernard-Tools/ABAP-Strust/src/zcl_strust2.clas.abap/c_version&label=Version&color=blue)

[![License](https://img.shields.io/github/license/Marc-Bernard-Tools/ABAP-Strust?label=License&color=success)](LICENSE)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg?color=success)](https://github.com/Marc-Bernard-Tools/.github/blob/main/CODE_OF_CONDUCT.md)
[![REUSE Status](https://api.reuse.software/badge/github.com/Marc-Bernard-Tools/ABAP-Strust)](https://api.reuse.software/info/github.com/Marc-Bernard-Tools/ABAP-Strust)

# Trust Management

Easy to use class for adding, updating, or removing certificates from ABAP Trust Management (transaction STRUST)

Made by [Marc Bernard Tools](https://marcbernardtools.com/) giving back to the [SAP Community](https://community.sap.com/)

NO WARRANTIES, [MIT License](LICENSE)

## Usage

Example of creating, updating, or removing a certificate using class `zcl_strust2`.

```abap
CONSTANTS:
  c_sslc    TYPE psecontext VALUE 'SSLC' ##NO_TEXT,
  c_anonym  TYPE ssfappl VALUE 'ANONYM' ##NO_TEXT,
  c_id      TYPE ssfid VALUE 'CN=%SID SSL client SSL Client (Standard), OU=%ORG, O=MBT, C=CA' ##NO_TEXT,
  c_org     TYPE string VALUE 'Marc Bernard Tools' ##NO_TEXT,
  c_subject TYPE string VALUE 'CN=*.marcbernardtools.com' ##NO_TEXT.

DATA:
  lo_strust TYPE REF TO zcl_strust2,
  lx_error  TYPE REF TO zcx_strust2.

TRY.
    CREATE OBJECT lo_strust
      EXPORTING
        iv_context = c_sslc
        iv_applic  = c_anonym.

    lo_strust->load(
      iv_create = abap_true
      iv_id     = c_id
      iv_org    = c_org ).

    lo_strust->get_own_certificate( ).

    lo_strust->get_certificate_list( ).

    IF iv_drop = abap_true.
      lo_strust->remove( c_subject ).
    ELSE.
      " Root and intermediate certificates
      " lo_strust->add( _get_certificate_ca( ) )
      " lo_strust->add( _get_certificate_ica( ) )
      lo_strust->add( _get_certificate_mbt( ) ). 
      lo_strust->update( ).
    ENDIF.

  CATCH zcx_strust2 INTO lx_error.
    MESSAGE lx_error TYPE 'I' DISPLAY LIKE 'E'.
ENDTRY.
```

The certificate for the `add` method needs to be provided as a table with the following format:

```txt
-----BEGIN CERTIFICATE-----
MIIGQDCCBSigAwIBAgIQCNqWSvYNNa9hfOzsk89rUjANBgkqhkiG9w0BAQsFADBg
MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
...
-----END CERTIFICATE-----
```

## Prerequisites

SAP Basis 7.02 or higher

## Installation

You can install this module using [abapGit](https://github.com/abapGit/abapGit) either creating a new online repository for https://github.com/Marc-Bernard-Tools/ABAP-Strust or downloading the repository [ZIP file](https://github.com/Marc-Bernard-Tools/ABAP-Strust/archive/main.zip) and creating a new offline repository.

Recommended SAP package: `$ABAP-STRUST`.

## Contributions

All contributions are welcome! Read our [Contribution Guidelines](CONTRIBUTING.md), fork this repo, and create a pull request.

## About

Made with :heart: in Canada

Copyright 2024 Marc Bernard <https://marcbernardtools.com/>

Follow [@marcfbe](https://twitter.com/marcfbe) on Twitter

<p><a href="https://marcbernardtools.com/"><img width="160" height="65" src="https://marcbernardtools.com/info/MBT_Logo_640x250_on_Gray.png" alt="MBT Logo"></a></p>
