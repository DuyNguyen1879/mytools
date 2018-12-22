#!/bin/sh
#
# simple usage: 
# wget -O /usr/lib/nagios/plugins/check_ssl_cert "https://git.io/fhJWr"
#
# check_ssl_cert
#
# Checks an X.509 certificate:
# - checks if the server is running and delivers a valid certificate
# - checks if the CA matches a given pattern
# - checks the validity
#
# See  the INSTALL file for installation instructions
#
# Copyright (c) 2007-2012 ETH Zurich.
# Copyright (c) 2007-2018 Matteo Corti <matteo@corti.li>
#
# This module is free software; you can redistribute it and/or modify it
# under the terms of GNU general public license (gpl) version 3.
# See the LICENSE file for details. 

################################################################################
# Constants

VERSION=1.72.0
SHORTNAME="SSL_CERT"

VALID_ATTRIBUTES=",startdate,enddate,subject,issuer,serial,modulus,serial,hash,email,ocsp_uri,fingerprint,"

SIGNALS="HUP INT QUIT TERM ABRT"

# return value for the creation of temporary files
TEMPFILE=""

################################################################################
# Functions

################################################################################
# Prints usage information
# Params
#   $1 error message (optional)
usage() {

    if [ -n "$1" ] ; then
        echo "Error: $1" 1>&2
    fi

    #### The following line is 80 characters long (helps to fit the help text in a standard terminal)
    ######--------------------------------------------------------------------------------

    echo
    echo "Usage: check_ssl_cert -H host [OPTIONS]"
    echo
    echo "Arguments:"
    echo "   -H,--host host             server"
    echo
    echo "Options:"
    echo "   -A,--noauth                ignore authority warnings (expiration only)"
    echo "      --altnames              matches the pattern specified in -n with alternate"
    echo "                              names too"
    echo "   -C,--clientcert path       use client certificate to authenticate"
    echo "      --clientpass phrase     set passphrase for client certificate."
    echo "   -c,--critical days         minimum number of days a certificate has to be valid"
    echo "                              to issue a critical status"
    echo "      --curl-bin path         path of the curl binary to be used"
    echo "   -d,--debug                 produces debugging output"
    echo "      --ecdsa                 cipher selection: force ECDSA authentication"
    echo "   -e,--email address         pattern to match the email address contained in the"
    echo "                              certificate"
    echo "   -f,--file file             local file path (works with -H localhost only)"
    echo "                              with -f you can not only pass a x509 certificate file"
    echo "                              but also a certificate revocation list (CRL) to check"
    echo "                              the validity period"
    echo "      --file-bin path         path of the file binary to be used"
    echo "      --fingerprint SHA1      pattern to match the SHA1-Fingerprint"
    echo "      --force-perl-date       force the usage of Perl for date computations"
    echo "      --format FORMAT         format output template on success, for example"
    echo "                              \"%SHORTNAME% OK %CN% from '%CA_ISSUER_MATCHED%'\""
    echo "   -h,--help,-?               this help message"
    echo "      --ignore-exp            ignore expiration date"
    echo "      --ignore-ocsp           do not check revocation with OCSP"
    echo "      --ignore-sig-alg        do not check if the certificate was signed with SHA1"
    echo "                              or MD5"
    echo "      --ignore-ssl-labs-cache Forces a new check by SSL Labs (see -L)"
    echo "   -i,--issuer issuer         pattern to match the issuer of the certificate"
    echo "      --issuer-cert-cache dir directory where to store issuer certificates cache"
    echo "   -L,--check-ssl-labs grade  SSL Labs assessment"
    echo "                              (please check https://www.ssllabs.com/about/terms.html)"
    echo "      --long-output list      append the specified comma separated (no spaces) list"
    echo "                              of attributes to the plugin output on additional lines"
    echo "                              Valid attributes are:"
    echo "                                enddate, startdate, subject, issuer, modulus,"
    echo "                                serial, hash, email, ocsp_uri and fingerprint."
    echo "                              'all' will include all the available attributes."
    echo "   -n,--cn name               pattern to match the CN of the certificate (can be"
    echo "                              specified multiple times)"
    echo "      --no_ssl2               disable SSL version 2"
    echo "      --no_ssl3               disable SSL version 3"
    echo "      --no_tls1               disable TLS version 1"
    echo "      --no_tls1_1             disable TLS version 1.1"
    echo "      --no_tls1_2             disable TLS version 1.2"
    echo "   -N,--host-cn               match CN with the host name"
    echo "   -o,--org org               pattern to match the organization of the certificate"
    echo "      --openssl path          path of the openssl binary to be used"
    echo "   -p,--port port             TCP port"
    echo "   -P,--protocol protocol     use the specific protocol"
    echo "                              {http|smtp|pop3|imap|ftp|xmpp|irc|ldap}"
    echo "                              http:                    default"
    echo "                              smtp,pop3,imap,ftp,ldap: switch to TLS"
    echo "   -s,--selfsigned            allows self-signed certificates"
    echo "      --serial serialnum      pattern to match the serial number"
    echo "      --sni name              sets the TLS SNI (Server Name Indication) extension"
    echo "                              in the ClientHello message to 'name'"
    echo "      --ssl2                  forces SSL version 2"
    echo "      --ssl3                  forces SSL version 3"
    echo "      --require-ocsp-stapling require OCSP stapling"
    echo "      --require-san           require the presence of a Subject Alternative Name"
    echo "                              extension"
    echo "   -r,--rootcert path         root certificate or directory to be used for"
    echo "                              certificate validation"
    echo "      --rsa                   cipher selection: force RSA authentication"
    echo "      --temp dir              directory where to store the temporary files"
    echo "      --terse                 terse output"
    echo "   -t,--timeout               seconds timeout after the specified time"
    echo "                              (defaults to 15 seconds)"
    echo "      --tls1                  force TLS version 1"
    echo "      --tls1_1                force TLS version 1.1"
    echo "      --tls1_2                force TLS version 1.2"
    echo "      --tls1_3                force TLS version 1.3"
    echo "   -v,--verbose               verbose output"
    echo "   -V,--version               version"
    echo "   -w,--warning days          minimum number of days a certificate has to be valid"
    echo "                              to issue a warning status"
    echo "      --xmpphost name         specifies the host for the 'to' attribute of the stream element"
    echo
    echo "Deprecated options:"
    echo "      --days days             minimum number of days a certificate has to be valid"
    echo "                              (see --critical and --warning)"
    echo "      --ocsp                  check revocation via OCSP"
    echo "   -S,--ssl version           force SSL version (2,3)"
    echo "                              (see: --ssl2 or --ssl3)"
    echo
    echo "Report bugs to https://github.com/matteocorti/check_ssl_cert/issues"
    echo

    exit 3

}

################################################################################
# trap passing the signal name
# see https://stackoverflow.com/questions/2175647/is-it-possible-to-detect-which-trap-signal-in-bash/2175751#2175751
trap_with_arg() {
    func="$1" ; shift
    for sig ; do
	# shellcheck disable=SC2064
        trap "$func $sig" "$sig"
    done
}

################################################################################
# Cleanup temporary files
remove_temporary_files() {
    if [ -n "${DEBUG}" ] ; then
	echo "[DBG] cleaning up temporary files"
	# shellcheck disable=SC2086
	echo $TEMPORARY_FILES | tr '\ ' '\n' | sed 's/^/[DBG]   /'
    fi    
    # shellcheck disable=SC2086
    rm $TEMPORARY_FILES
}

################################################################################
# Cleanup when exiting
cleanup() {
    SIGNAL=$1
    if [ -n "${DEBUG}" ] ; then
	echo "[DBG] signal caught $SIGNAL"
    fi
    remove_temporary_files
    # shellcheck disable=SC2086
    trap - $SIGNALS
    exit
}

create_temporary_file() {

    # create a temporary file
    TEMPFILE="$( mktemp -t "${0##*/}XXXXXX" 2> /dev/null )"
    if [ -z "${TEMPFILE}" ] || [ ! -w "${TEMPFILE}" ] ; then
        unknown 'temporary file creation failure.'
    fi

    if [ -n "${DEBUG}" ] ; then
	echo "[DBG] temporary file $TEMPFILE created"
    fi
    
    # add the file to the list of temporary files
    TEMPORARY_FILES="$TEMPORARY_FILES $TEMPFILE"
    
}

################################################################################
# Exits with a critical message
# Params
#   $1 error message
critical() {
    if [ -n "${HOST}" ] ; then
        tmp=" ${HOST}"
    fi
    remove_temporary_files
    printf '%s CRITICAL%s: %s%s%s\n' "${SHORTNAME}" "${tmp}" "$1" "${PERFORMANCE_DATA}" "${LONG_OUTPUT}"
    exit 2
}

################################################################################
# Exits with a warning message
# Param
#   $1 warning message
warning() {
    if [ -n "${HOST}" ] ; then
        tmp=" ${HOST}"
    fi
    remove_temporary_files
    printf '%s WARN%s: %s%s%s\n' "${SHORTNAME}" "${tmp}" "$1" "${PERFORMANCE_DATA}" "${LONG_OUTPUT}"
    exit 1
}

################################################################################
# Exits with an 'unknown' status
# Param
#   $1 message
unknown() {
    if [ -n "${HOST}" ] ; then
        tmp=" ${HOST}"
    fi
    remove_temporary_files
    printf '%s UNKNOWN%s: %s\n' "${SHORTNAME}" "${tmp}" "$1"
    exit 3
}

################################################################################
# Executes command with a timeout
# Params:
#   $1 timeout in seconds
#   $2 command
# Returns 1 if timed out 0 otherwise
exec_with_timeout() {

    time=$1

    # start the command in a subshell to avoid problem with pipes
    # (spawn accepts one command)
    command="/bin/sh -c \"$2\""

    if [ -n "${DEBUG}" ] ; then
        echo "[DBG] executing with timeout (${time}s): $2"
    fi

    if [ -n "${TIMEOUT_BIN}" ] ; then

        if [ -n "${DEBUG}" ] ; then
            echo "[DBG]   ${TIMEOUT_BIN} $time $command"
        fi

        eval "${TIMEOUT_BIN} $time $command" > /dev/null 2>&1

        if [ $? = 137 ] ; then
            critical "Timeout after ${time} seconds"
        fi

    elif [ -n "${EXPECT}" ] ; then

        expect -c "set echo \"-noecho\"; set timeout $time; spawn -noecho $command; expect timeout { exit 1 } eof { exit 0 }"

        if [ $? = 1 ] ; then
            critical "Timeout after ${time} seconds"
        fi

    else

        eval "${command}"

    fi

}

################################################################################
# Checks if a given program is available and executable
# Params
#   $1 program name
# Returns 1 if the program exists and is executable
check_required_prog() {

    PROG=$(command -v "$1" 2> /dev/null)

    if [ -z "$PROG" ] ; then
        critical "cannot find program: $1"
    fi

    if [ ! -x "$PROG" ] ; then
        critical "$PROG is not executable"
    fi

}

################################################################################
# Converts SSL Labs grades to a numeric value
#   (see https://www.ssllabs.com/downloads/SSL_Server_Rating_Guide.pdf)
# Params
#   $1 program name
# Sets NUMERIC_SSL_LAB_GRADE
convert_ssl_lab_grade() {

    GRADE="$1"

    unset NUMERIC_SSL_LAB_GRADE

    case "${GRADE}" in
        'A+'|'a+')
            # Value not in documentation
            NUMERIC_SSL_LAB_GRADE=85
            shift
            ;;
        A|a)
            NUMERIC_SSL_LAB_GRADE=80
            shift
            ;;
        'A-'|'a-')
            # Value not in documentation
            NUMERIC_SSL_LAB_GRADE=75
            shift
            ;;
        B|b)
            NUMERIC_SSL_LAB_GRADE=65
            shift
            ;;
        C|c)
            NUMERIC_SSL_LAB_GRADE=50
            shift
            ;;
        D|d)
            NUMERIC_SSL_LAB_GRADE=35
            shift
            ;;
        E|e)
            NUMERIC_SSL_LAB_GRADE=20
            shift
            ;;
        F|f)
            NUMERIC_SSL_LAB_GRADE=0
            shift
            ;;
        T|t)
            # No trust: value not in documentation
            NUMERIC_SSL_LAB_GRADE=0
            shift
            ;;
        M|m)
            # Certificate name mismatch: value not in documentation
            NUMERIC_SSL_LAB_GRADE=0
            shift
            ;;
        *)
            unknown "Connot convert SSL Lab grade ${GRADE}"
            ;;
    esac

}

################################################################################
# Tries to fetch the certificate

fetch_certificate() {

    RET=0

    # IPv6 addresses need brackets in a URI
    if [ "${HOST}" != "${HOST#*[0-9].[0-9]}" ]; then
       if [ -n "${DEBUG}" ] ; then
           echo "[DBG] ${HOST} is an IPv4 address"
       fi
    elif [ "${HOST}" != "${HOST#*:[0-9a-fA-F]}" ]; then
       if [ -n "${DEBUG}" ] ; then
           echo "[DBG] ${HOST} is an IPv6 address"
       fi
       if [ -z "${HOST##*[*}" ] ; then
	   if [ -n "${DEBUG}" ] ; then
               echo "[DBG] ${HOST} is already specified with brakcets"
	   fi
       else
	   if [ -n "${DEBUG}" ] ; then
               echo "[DBG] adding brackets to ${HOST}"
	   fi
	   HOST="[${HOST}]"	   
       fi
    else
       if [ -n "${DEBUG}" ] ; then
           echo "[DBG] ${HOST} is not an IP address"
       fi
    fi
    
    # Check if a protocol was specified (if not HTTP switch to TLS)
    if [ -n "${PROTOCOL}" ] && [ "${PROTOCOL}" != "http" ] && [ "${PROTOCOL}" != "https" ] ; then

        case "${PROTOCOL}" in
            smtp)
                exec_with_timeout "$TIMEOUT" "echo -e 'QUIT\\r' | $OPENSSL s_client ${CLIENT} ${CLIENTPASS} -starttls ${PROTOCOL} -connect $HOST:$PORT ${SERVERNAME} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} 2> ${ERROR} 1> ${CERT}"
                RET=$?
                ;;
            irc)
                exec_with_timeout "$TIMEOUT" "echo -e 'QUIT\\r' | $OPENSSL s_client ${CLIENT} ${CLIENTPASS} -connect $HOST:$PORT ${SERVERNAME} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} 2> ${ERROR} 1> ${CERT}"
                RET=$?
                ;;
            pop3|imap|ftp|ldap)
                exec_with_timeout "$TIMEOUT" "echo 'Q' | $OPENSSL s_client ${CLIENT} ${CLIENTPASS} -starttls ${PROTOCOL} -connect $HOST:$PORT ${SERVERNAME} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} 2> ${ERROR} 1> ${CERT}"
                RET=$?
                ;;
	    xmpp)
                exec_with_timeout "$TIMEOUT" "echo 'Q' | $OPENSSL s_client ${CLIENT} ${CLIENTPASS} -starttls ${PROTOCOL} -connect $HOST:$XMPPPORT ${XMPPHOST} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} 2> ${ERROR} 1> ${CERT}"
                RET=$?
                ;;
            *)
                unknown "Error: unsupported protocol ${PROTOCOL}"
                ;;
        esac

    elif [ -n "${FILE}" ] ; then

        if [ "${HOST}" = "localhost" ] ; then
            exec_with_timeout "$TIMEOUT" "/bin/cat '${FILE}' 2> ${ERROR} 1> ${CERT}"
            RET=$?
        else
            unknown "Error: option 'file' works with -H localhost only"
        fi

    else

        exec_with_timeout "$TIMEOUT" "echo 'Q' | $OPENSSL s_client ${CLIENT} ${CLIENTPASS} -connect $HOST:$PORT ${SERVERNAME} -verify 6 ${ROOT_CA} ${SSL_VERSION} ${SSL_VERSION_DISABLED} ${SSL_AU} 2> ${ERROR} 1> ${CERT}"
        RET=$?

    fi

    if [ -n "${DEBUG}" ] ; then
        echo "[DBG] storing a copy of the retrieved certificate in ${HOST}.crt"
        cp "${CERT}" "${HOST}.crt"

        echo "[DBG] storing a copy of the OpenSSL errors in ${HOST}.error"
        cp "${ERROR}" "${HOST}.error"

    fi

    if [ "${RET}" -ne 0 ] ; then

        if [ -n "${DEBUG}" ] ; then
            sed 's/^/[DBG] SSL error: /' "${ERROR}"
        fi

        # s_client could verify the server certificate because the server requires a client certificate
        if grep -q '^Acceptable client certificate CA names' "${CERT}" ; then

            if [ -n "${VERBOSE}" ] ; then
                echo "The server requires a client certificate"
            fi

        else

            # Try to clean up the error message
            #     Remove the 'verify and depth' lines
            #     Take the 1st line (seems OK with the use cases I tested)
            ERROR_MESSAGE=$(
                grep -v '^depth' "${ERROR}" \
                    | grep -v '^verify' \
                    | head -n 1
                 )
            critical "SSL error: ${ERROR_MESSAGE}"

        fi

    fi

}

################################################################################
# Adds metric to performance data
# Params
#   $1 performance data in nagios plugin format,
#      see https://nagios-plugins.org/doc/guidelines.html#AEN200
add_performance_data() {
    if [ -z "${PERFORMANCE_DATA}" ]; then
        PERFORMANCE_DATA="|${1}"
    else
        PERFORMANCE_DATA="${PERFORMANCE_DATA} $1"
    fi
}

################################################################################
# Prepares sed-style command for variable replacement
# Params
#   $1 variable name (e.g. SHORTNAME)
#   $2 variable value (e.g. SSL_CERT)
var_for_sed() {
    echo "s|%$1%|$( echo "$2" | sed -e 's#|#\\\\|#g' )|g"
}

################################################################################
# Main
################################################################################
main() {

    # Default values
    DEBUG=""
    OPENSSL=""
    FILE_BIN=""
    CURL_BIN=""
    IGNORE_SSL_LABS_CACHE=""
    PORT="443"
    XMPPPORT="5222"
    XMPPHOST=""
    SNI=""
    TIMEOUT="15"
    VERBOSE=""
    FORCE_PERL_DATE=""
    REQUIRE_SAN=""
    REQUIRE_OCSP_STAPLING=""
    OCSP="1" # enabled by default
    FORMAT=""

    # Set the default temp dir if not set
    if [ -z "${TMPDIR}" ] ; then
        TMPDIR="/tmp"
    fi

    ################################################################################
    # Process command line options
    #
    # We do no use getopts since it is unable to process long options

    while true; do

        case "$1" in
            ########################################
            # Options without arguments
            -A|--noauth)
                NOAUTH=1
                shift
                ;;
            --altnames)
                ALTNAMES=1
                shift
                ;;
            -d|--debug)
                DEBUG=1
                VERBOSE=1
                shift
                ;;
            -h|--help|-\?)
                usage
                exit 0
                ;;
            --force-perl-date)
                FORCE_PERL_DATE=1
                shift
                ;;
            --ignore-exp)
                NOEXP=1
                shift
                ;;
            --ignore-sig-alg)
                NOSIGALG=1
                shift
                ;;
            --ignore-ssl-labs-cache)
                IGNORE_SSL_LABS_CACHE="&startNew=on"
                shift
                ;;
            --no_ssl2)
                SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_ssl2"
                shift
                ;;
            --no_ssl3)
                SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_ssl3"
                shift
                ;;
            --no_tls1)
                SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_tls1"
                shift
                ;;
            --no_tls1_1)
                SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_tls1_1"
                shift
                ;;
            --no_tls1_2)
                SSL_VERSION_DISABLED="${SSL_VERSION_DISABLED} -no_tls1_2"
                shift
                ;;
            -N|--host-cn)
                COMMON_NAME="__HOST__"
                shift
                ;;
            -s|--selfsigned)
                SELFSIGNED=1
                shift
                ;;
            --rsa)
                SSL_AU="-cipher aRSA"
                shift
                ;;
            --ecdsa)
                SSL_AU="-cipher aECDSA"
                shift
                ;;
            --ssl2)
                SSL_VERSION="-ssl2"
                shift
                ;;
            --ssl3)
                SSL_VERSION="-ssl3"
                shift
                ;;
            --tls1)
                SSL_VERSION="-tls1"
                shift
                ;;
            --tls1_1)
                SSL_VERSION="-tls1_1"
                shift
                ;;
            --tls1_2)
                SSL_VERSION="-tls1_2"
                shift
                ;;
            --tls1_3)
                SSL_VERSION="-tls1_3"
                shift
                ;;                
            --ocsp)
                # deprecated
                shift
                ;;
            --ignore-ocsp)
                OCSP=""
                shift
                ;;
            --terse)
                TERSE=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -V|--version)
                echo "check_ssl_cert version ${VERSION}"
                exit 3
                ;;
            ########################################
            # Options with arguments
            -c|--critical)
                if [ $# -gt 1 ]; then
                    CRITICAL="$2"
                    shift 2
                else
                   unknown "-c,--critical requires an argument"
                fi
                ;;
            --curl-bin)
                if [ $# -gt 1 ]; then
                    CURL_BIN="$2"
                    shift 2
                else
                    unknown "--curl-bin requires an argument"
                fi
                ;;
            # Deprecated option: used to be as --warning
            --days)
                if [ $# -gt 1 ]; then
                    WARNING="$2"
                    shift 2
                else
                    unknown "-d,--days requires an argument"
                fi
                ;;
            -e|--email)
                if [ $# -gt 1 ]; then
                    ADDR="$2"
                    shift 2
                else
                    unknown "-e,--email requires an argument"
                fi
                ;;
            -f|--file)
                if [ $# -gt 1 ]; then
                    FILE="$2"
                    shift 2
                else
                    unknown "-f,--file requires an argument"
                fi
                ;;
            --file-bin)
                if [ $# -gt 1 ]; then
                    FILE_BIN="$2"
                    shift 2
                else
                    unknown "--file-bin requires an argument"
                fi
                ;;
             --format)
                if [ $# -gt 1 ]; then
                    FORMAT="$2"
                    shift 2
                else
                    unknown "-format requires an argument"
                fi
                ;;
            -H|--host)
                if [ $# -gt 1 ]; then
                    HOST="$2"
                    shift 2
                else
                    unknown "-H,--host requires an argument"
                fi
                ;;
            -i|--issuer)
                if [ $# -gt 1 ]; then
                    ISSUER="$2"
                    shift 2
                else
                    unknown "-i,--issuer requires an argument"s
                fi
                ;;
            --issuer-cert-cache)
                if [ $# -gt 1 ]; then
                    ISSUER_CERT_CACHE="$2"
                    shift 2
                else
                    unknown "--issuer-cert-cache requires an argument"
                fi
                ;;
            -L|--check-ssl-labs)
                if [ $# -gt 1 ]; then
                    SSL_LAB_ASSESSMENT="$2"
                    shift 2
                else
                    unknown "-L|--check-ssl-labs requires an argument"
                fi
                ;;
            --serial)
                if [ $# -gt 1 ]; then
                    SERIAL_LOCK="$2"
                    shift 2
                else
                    unknown "--serial requires an argument"
                fi
                ;;
            --fingerprint)
                if [ $# -gt 1 ]; then
                    FINGERPRINT_LOCK="$2"
                    shift 2
                else
                    unknown "--fingerprint requires an argument - SHA1 Fingerprint"
                fi
                ;;
            --long-output)
                if [ $# -gt 1 ]; then
                    LONG_OUTPUT_ATTR="$2"
                    shift 2
               else
                    unknown "--long-output requires an argument"
               fi
               ;;
            -n|--cn)
                if [ $# -gt 1 ]; then
                    if [ -n "${COMMON_NAME}" ]; then
                      COMMON_NAME="${COMMON_NAME} ${2}"
                    else
                              COMMON_NAME="${2}"
                    fi
                    shift 2
                else
                    unknown "-n,--cn requires an argument"
                fi
                ;;
            -o|--org)
                if [ $# -gt 1 ]; then
                    ORGANIZATION="$2"
                    shift 2
                else
                    unknown "-o,--org requires an argument"
                fi
                ;;
            --openssl)
                if [ $# -gt 1 ]; then
                    OPENSSL="$2"
                    shift 2
                else
                    unknown "--openssl requires an argument"
                fi
                ;;
            -p|--port)
                if [ $# -gt 1 ]; then
                    PORT="$2"
		    XMPPPORT="$2"
                    shift 2
                else
                    unknown "-p,--port requires an argument"
                fi
                ;;
            -P|--protocol)
                if [ $# -gt 1 ]; then
                    PROTOCOL="$2"
                    shift 2
                else
                    unknown "-P,--protocol requires an argument"
                fi
                ;;
            -r|--rootcert)
                if [ $# -gt 1 ]; then
                    ROOT_CA="$2"
                    shift 2
                else
                    unknown "-r,--rootcert requires an argument"
                fi
                ;;
            -C|--clientcert)
                if [ $# -gt 1 ]; then
                    CLIENT_CERT="$2"
                    shift 2
                else
                    unknown "-c,--clientcert requires an argument"
                fi
                ;;
            --clientpass)
                if [ $# -gt 1 ]; then
                    CLIENT_PASS="$2"
                    shift 2
                else
                    unknown "--clientpass requires an argument"
                fi
                ;;
            --require-ocsp-stapling)
		REQUIRE_OCSP_STAPLING=1
		shift
		;;
            --require-san)
                REQUIRE_SAN=1
                shift
                ;;
            --sni)
                if [ $# -gt 1 ]; then
                    SNI="$2"
                    shift 2
                else
                    unknown "--sni requires an argument"
                fi
                ;;
            -S|--ssl)
                if [ $# -gt 1 ]; then

                    if [ "$2" = "2" ] || [ "$2" = "3" ] ; then
                        SSL_VERSION="-ssl${2}"
                        shift 2
                    else
                        unknown "invalid argument for --ssl"
                    fi

                else

                    unknown "--ssl requires an argument"

                fi
                ;;
            -t|--timeout)
                if [ $# -gt 1 ]; then
                    TIMEOUT="$2"
                    shift 2
                else
                    unknown "-t,--timeout requires an argument"
                fi
                ;;
            --temp)
                if [ $# -gt 1 ] ; then
                    # Override TMPDIR
                    TMPDIR="$2"
                    shift 2
                else
                    unknown "--temp requires an argument"
                fi
                ;;
            -w|--warning)
                if [ $# -gt 1 ]; then
                    WARNING="$2"
                    shift 2
                else
                    unknown "-w,--warning requires an argument"
                fi
                ;;
	    --xmpphost)
		if [ $# -gt 1 ]; then
                    XMPPHOST="$2"
                    shift 2
                else
                    unknown "--xmpphost requires an argument"
                fi
                ;;
            ########################################
            # Special
            --)
                shift
                break
                ;;
            -*)
                unknown "invalid option: ${1}"
                ;;
            *)
                if [ -n "$1" ] ; then
                    unknown "invalid option: ${1}"
                fi
                break
                ;;
        esac

    done

    ################################################################################
    # Set COMMON_NAME to hostname if -N was given as argument
    if [ "$COMMON_NAME" = "__HOST__" ] ; then
        COMMON_NAME="${HOST}"
    fi

    ################################################################################
    # Sanity checks

    ###############
    # Check options
    if [ -z "${HOST}" ] ; then
        usage "No host specified"
    fi

    if [ -n "${ALTNAMES}" ] && [ -z "${COMMON_NAME}" ] ; then
        unknown "--altnames requires a common name to match (--cn or --host-cn)"
    fi

    if [ -n "${ROOT_CA}" ] ; then

        if [ ! -r "${ROOT_CA}" ] ; then
            unknown "Cannot read root certificate ${ROOT_CA}"
        fi

        if [ -d "${ROOT_CA}" ] ; then
            ROOT_CA="-CApath ${ROOT_CA}"
        elif [ -f "${ROOT_CA}" ] ; then
            ROOT_CA="-CAfile ${ROOT_CA}"
        else
            unknown "Root certificate of unknown type $(file "${ROOT_CA}" 2> /dev/null)"
        fi

    fi

    if [ -n "${CLIENT_CERT}" ] ; then

        if [ ! -r "${CLIENT_CERT}" ] ; then
            unknown "Cannot read client certificate ${CLIENT_CERT}"
        fi

    fi

    if [ -n "${CRITICAL}" ] ; then

        if ! echo "${CRITICAL}" | grep -q '[0-9][0-9]*' ; then
            unknown "invalid number of days ${CRITICAL}"
        fi

    fi

    if [ -n "${WARNING}" ] ; then

        if ! echo "${WARNING}" | grep -q '[0-9][0-9]*' ; then
            unknown "invalid number of days ${WARNING}"
        fi

    fi

    if [ -n "${CRITICAL}" ] && [ -n "${WARNING}" ] ; then

        if [ "${WARNING}" -le "${CRITICAL}" ] ; then
            unknown "--warning (${WARNING}) is less than or equal to --critical (${CRITICAL})"
        fi

    fi

    if [ -n "${TMPDIR}" ] ; then

        if [ ! -d "${TMPDIR}" ] ; then
            unknown "${TMPDIR} is not a directory";
        fi

        if [ ! -w "${TMPDIR}" ] ; then
            unknown "${TMPDIR} is not writable";
        fi

    fi

    if [ -n "${OPENSSL}" ] ; then

        if [ ! -x "${OPENSSL}" ] ; then
            unknown "${OPENSSL} ist not an executable"
        fi

        #if ! "${OPENSSL}" list-standard-commands | grep -q s_client ; then
        #    unknown "${OPENSSL} ist not an openssl executable"
        #fi

    fi

    if [ -n "${SSL_LAB_ASSESSMENT}" ] ; then
        convert_ssl_lab_grade "${SSL_LAB_ASSESSMENT}"
        SSL_LAB_ASSESSMENT_NUMERIC="${NUMERIC_SSL_LAB_GRADE}"
    fi

    if [ -n "${DEBUG}" ] ; then
        echo "[DBG] ROOT_CA = ${ROOT_CA}"
    fi

    #######################
    # Check needed programs

    # OpenSSL
    if [ -z "${OPENSSL}" ] ; then
        check_required_prog openssl
        OPENSSL=$PROG
    fi

    # file
    if [ -z "${FILE_BIN}" ] ; then
        check_required_prog file
        FILE_BIN=$PROG
    fi
    
    # curl
    if [ -z "${CURL_BIN}" ] ; then
	if [ -n "${SSL_LAB_ASSESSMENT}" ] || [ -n "${OCSP}" ] ; then
	    if [ -n "${DEBUG}" ] ; then
		echo "[DBG] cURL binary needed. SSL Labs = ${SSL_LAB_ASSESSMENT}, OCSP = ${OCSP}"
		echo "[DBG] cURL binary not specified"
	    fi
            check_required_prog curl
            CURL_BIN=$PROG
	    if [ -n "${DEBUG}" ] ; then
		echo "[DBG] cURL available: ${CURL_BIN}"
	    fi
	else
	    if [ -n "${DEBUG}" ] ; then
		echo "[DBG] cURL binary not needed. SSL Labs = ${SSL_LAB_ASSESSMENT}, OCSP = ${OCSP}"
	    fi
	fi
    fi
    
    # Expect (optional)
    EXPECT="$(command -v expect 2> /dev/null)"
    test -x "${EXPECT}" || EXPECT=""
    if [  -n "${VERBOSE}" ] ; then
        if [ -z "${EXPECT}" ] ; then
            echo "expect not available"
        else
            echo "expect available (${EXPECT})"
        fi
    fi

    # Timeout (optional)
    TIMEOUT_BIN="$(command -v timeout 2> /dev/null)"
    test -x "${TIMEOUT_BIN}" || TIMEOUT_BIN=""
    if [  -n "${VERBOSE}" ] ; then

        if [ -z "${TIMEOUT_BIN}" ] ; then
            echo "timeout not available"
        else
            echo "timeout available (${TIMEOUT_BIN})"
        fi

    fi

    if [ -z "${TIMEOUT_BIN}" ] && [ -z "${EXPECT}" ] && [ -n "${VERBOSE}" ] ; then
        echo "disabling timeouts"
    fi

    PERL="$(command -v perl 2> /dev/null)"

    if [ -n "${DEBUG}" ] && [ -n "${PERL}" ] ; then
        echo "[DBG] perl available: ${PERL}"
    fi

    DATEBIN="$(command -v date 2> /dev/null)"

    if [ -n "${DEBUG}" ] && [ -n "${DATEBIN}" ] ; then
        echo "[DBG] date available: ${DATEBIN}"
    fi

    DATETYPE=""

    if ! "${DATEBIN}" +%s >/dev/null 2>&1  ;  then

        # Perl with Date::Parse (optional)
        test -x "${PERL}" || PERL=""
        if [ -z "${PERL}" ] && [ -n "${VERBOSE}" ] ; then
            echo "Perl not found: disabling date computations"
        fi

        if ! ${PERL} -e "use Date::Parse;" > /dev/null 2>&1 ; then

            if [ -n "${VERBOSE}" ] ; then
                echo "Perl module Date::Parse not installed: disabling date computations"
            fi

            PERL=""

        else

            if [ -n "${VERBOSE}" ] ; then
                echo "Perl module Date::Parse installed: enabling date computations"
            fi

            DATETYPE="PERL"

        fi

    else

        if $DATEBIN --version >/dev/null 2>&1 ; then
            DATETYPE="GNU"
        else
            DATETYPE="BSD"
        fi

        if [ -n "${VERBOSE}" ] ; then
            echo "found ${DATETYPE} date with timestamp support: enabling date computations"
        fi

    fi

    if [ -n "${FORCE_PERL_DATE}" ] ; then
        DATETYPE="PERL"
    fi

    if [ -n "${DEBUG}" ] ; then
        echo "[DBG] check_ssl_cert version: ${VERSION}"
        echo "[DBG] OpenSSL binary: ${OPENSSL}"
        echo "[DBG] OpenSSL version: $( ${OPENSSL} version )"

	OPENSSL_DIR="$( ${OPENSSL} version -d | sed -E 's/OPENSSLDIR: "([^"]*)"/\1/' )"	

	echo "[DBG] OpenSSL configuration directory: ${OPENSSL_DIR}"

	DEFAULT_CA=0
	if [ -f "${OPENSSL_DIR}"/cert.pem ] ; then
	    DEFAULT_CA="$( grep -c BEGIN "${OPENSSL_DIR}"/cert.pem )"
	elif [ -f "${OPENSSL_DIR}"/certs ] ; then
	    DEFAULT_CA="$( grep -c BEGIN "${OPENSSL_DIR}"/certs )"
	fi
	echo "[DBG] ${DEFAULT_CA} root certificates installed by default"
	
        echo "[DBG] System info: $( uname -a )"
        echo "[DBG] Date computation: ${DATETYPE}"
    fi

    ################################################################################
    # Check if openssl s_client supports the -servername option
    #
    #   openssl s_client now has a -help option, so we can use that.
    #   Some older versions support -servername, but not -help
    #   => We supply an invalid command line option to get the help
    #      on standard error for these intermediate versions.
    #
    SERVERNAME=
    if ${OPENSSL} s_client -help 2>&1 | grep -q -- -servername || ${OPENSSL} s_client not_a_real_option 2>&1 | grep -q -- -servername; then

        if [ -n "${SNI}" ]; then
            SERVERNAME="-servername ${SNI}"
        else
            SERVERNAME="-servername ${HOST}"
        fi

        if [ -n "${DEBUG}" ] ; then
            echo "[DBG] '${OPENSSL} s_client' supports '-servername': using ${SERVERNAME}"
        fi

    else

        if [ -n "${VERBOSE}" ] ; then
            echo "'${OPENSSL} s_client' does not support '-servername': disabling virtual server support"
        fi

    fi

    ################################################################################
    # Check if openssl s_client supports the -xmpphost option
    #
    if ${OPENSSL} s_client -help 2>&1 | grep -q -- -xmpphost ; then

        XMPPHOST="-xmpphost ${XMPPHOST:-$HOST}"

        if [ -n "${DEBUG}" ] ; then
            echo "[DBG] '${OPENSSL} s_client' supports '-xmpphost': using ${XMPPHOST}"
        fi

    else

	if [ -n "${XMPPHOST}" ] ; then
	    unknown " s_client' does not support '-xmpphost'"
	fi
	
	XMPPHOST=
	
        if [ -n "${VERBOSE}" ] ; then
            echo "'${OPENSSL} s_client' does not support '-xmpphost': disabling 'to' attribute"
        fi

    fi

    ################################################################################
    # check if openssl s_client supports the SSL TLS version
    if [ -n "${SSL_VERSION}" ] ; then
	if ! "${OPENSSL}" s_client -help 2>&1 | grep -q -- "${SSL_VERSION}" ; then
	    unknown "OpenSSL does not support the ${SSL_VERSION} version"
	fi    
    fi
    
    ################################################################################
    # Fetch the X.509 certificate

    # Temporary storage for the certificate and the errors
    create_temporary_file; CERT=$TEMPFILE
    create_temporary_file; ERROR=$TEMPFILE

    if [ -n "${OCSP}" ] ; then

	create_temporary_file; ISSUER_CERT_TMP=$TEMPFILE
	create_temporary_file; ISSUER_CERT_TMP2=$TEMPFILE

    fi

    if [ -n "${REQUIRE_OCSP_STAPLING}" ] ; then
	create_temporary_file; OCSP_RESPONSE_TMP=$TEMPFILE
    fi
    
    if [ -n "${VERBOSE}" ] ; then
        echo "downloading certificate to ${TMPDIR}"
    fi

    CLIENT=""
    if [ -n "${CLIENT_CERT}" ] ; then
        CLIENT="-cert ${CLIENT_CERT}"
    fi

    CLIENTPASS=""
    if [ -n "${CLIENT_PASS}" ] ; then
        CLIENTPASS="-pass pass:${CLIENT_PASS}"
    fi

    # Cleanup before program termination
    # Using named signals to be POSIX compliant
    # shellcheck disable=SC2086
    trap_with_arg cleanup $SIGNALS

    fetch_certificate

    if grep -q 'sslv3\ alert\ unexpected\ message' "${ERROR}" ; then

        if [ -n "${SERVERNAME}" ] ; then

            # Some OpenSSL versions have problems with the -servername option
            # We try without
            if [ -n "${VERBOSE}" ] ; then
                echo "'${OPENSSL} s_client' returned an error: trying without '-servername'"
            fi

            SERVERNAME=""
            fetch_certificate

        fi

        if grep -q 'sslv3\ alert\ unexpected\ message' "${ERROR}" ; then

            critical "cannot fetch certificate: OpenSSL got an unexpected message"

        fi

    fi

    if grep -q "BEGIN X509 CRL" "${CERT}" ; then
        # we are dealing with a CRL file
        OPENSSL_COMMAND="crl"
        OPENSSL_PARAMS="-nameopt utf8,oneline,-esc_msb"
        OPENSSL_ENDDATE_OPTION="-nextupdate"
    else
        # look if we are dealing with a regular certificate file (x509)
        if ! grep -q "CERTIFICATE" "${CERT}" ; then

            if [ -n "${FILE}" ] ; then
                if "${OPENSSL}" crl -in "${CERT}" -inform DER | grep -q "BEGIN X509 CRL" ; then
                    if [ -n "${VERBOSE}" ] ; then
                        echo "File is DER encoded CRL"
                    fi
                    OPENSSL_COMMAND="crl"
                    OPENSSL_PARAMS="-inform DER -nameopt utf8,oneline,-esc_msb"
                    OPENSSL_ENDDATE_OPTION="-nextupdate"
                else
                    critical "'${FILE}' is not a valid certificate file"
                fi
            else
                # See
                # http://stackoverflow.com/questions/1251999/sed-how-can-i-replace-a-newline-n
                #
                # - create a branch label via :a
                # - the N command appends a newline and and the next line of the input
                #   file to the pattern space
                # - if we are before the last line, branch to the created label $!ba
                #   ($! means not to do it on the last line (as there should be one final newline))
                # - finally the substitution replaces every newline with a space on
                #   the pattern space
                ERROR_MESSAGE="$(sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/; /g' "${ERROR}")"
                if [ -n "${VERBOSE}" ] ; then
                    echo "Error: ${ERROR_MESSAGE}"
                fi
                critical "No certificate returned"
            fi
        else
            # parameters for regular x509 certifcates
            OPENSSL_COMMAND="x509"
            OPENSSL_PARAMS="-nameopt utf8,oneline,-esc_msb"
            OPENSSL_ENDDATE_OPTION="-enddate"
        fi

    fi

    if [ -n "${VERBOSE}" ] ; then
        echo "parsing the ${OPENSSL_COMMAND} certificate file"
    fi

    ################################################################################
    # Parse the X.509 certificate or crl

    # shellcheck disable=SC2086
    DATE="$($OPENSSL "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" ${OPENSSL_ENDDATE_OPTION} -noout | sed -e "s/^notAfter=//" -e "s/^nextUpdate=//")"

    if [ ${OPENSSL_COMMAND} = "crl" ]; then
        CN=""
        SUBJECT=""
        SERIAL=0
        OCSP_URI=""
        VALID_ATTRIBUTES=",lastupdate,nextupdate,issuer,"
    else
        # we need to remove everything before 'CN = ', to remove an eventual email supplied with / and additional elements (after ', ')
        CN="$($OPENSSL x509 -in "${CERT}" -subject -noout -nameopt utf8,oneline,-esc_msb |
            sed -e "s/^.*[[:space:]]*CN[[:space:]]=[[:space:]]//"  -e "s/\\/[[:alpha:]][[:alpha:]]*=.*\$//" -e "s/,.*//" )"

        SUBJECT="$($OPENSSL x509 -in "${CERT}" -subject -noout -nameopt utf8,oneline,-esc_msb)"

        SERIAL="$($OPENSSL x509 -in "${CERT}" -serial -noout  | sed -e "s/^serial=//")"
	
	FINGERPRINT="$($OPENSSL x509 -in "${CERT}" -fingerprint -sha1 -noout  | sed -e "s/^SHA1 Fingerprint=//")"

	# TO DO: we just take the first result: a loop over all the hosts should 
	# shellcheck disable=SC2086
        OCSP_URI="$($OPENSSL "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" -ocsp_uri -noout | head -n 1)"
    fi

    # Handle properly openssl x509 -issuer -noout output format differences:
    # OpenSSL 1.1.0: issuer=C = XY, ST = Alpha, L = Bravo, O = Charlie, CN = Charlie SSL CA
    # OpenSSL 1.0.2: issuer= /C=XY/ST=Alpha/L=Bravo/O=Charlie/CN=Charlie SSL CA 3
    # shellcheck disable=SC2086
    CA_O="$($OPENSSL "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" -issuer -noout | sed -e "s/^.*\\/O=//" -e "s/^.*, O = //" -e "s/\\/[A-Z][A-Z]*=.*\$//" -e "s/, [A-Z][A-Z]* =.*\$//")"
    # shellcheck disable=SC2086
    CA_CN="$($OPENSSL "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" -issuer -noout  | sed -e "s/^.*\\/CN=//" -e "s/^.*, CN = //" -e "s/\\/[A-Za-z][A-Za-z]*=.*\$//" -e "s/, [A-Z][A-Z]* =.*\$//")"

    # we just consider the first URI
    # shellcheck disable=SC2086
    ISSUER_URI="$($OPENSSL "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" -text -noout | grep "CA Issuers" | head -n 1 | sed -e "s/^.*CA Issuers - URI://")"

    if [ -z "${ISSUER_URI}" ] ; then
        if [ -n "${VERBOSE}" ] ; then
            echo "cannot find the CA Issuers in the certificate: disabling OCSP checks"
        fi
        OCSP=""
    elif ! echo "${ISSUER_URI}" | grep -qi '^http' ; then
        if [ -n "${VERBOSE}" ] ; then
            echo "unable to fetch the CA issuer certificate (unsupported protocol)"
        fi
        OCSP=""
    fi

    # Check OCSP stapling
    if [ -n "${REQUIRE_OCSP_STAPLING}" ] ; then
	
	if [ -n "${VERBOSE}" ] ; then
       	    echo "checking OCSP stapling"
	fi

	exec_with_timeout "$TIMEOUT" "echo QUIT | openssl s_client -connect ${HOST}:${PORT} ${SERVERNAME} -status 2> /dev/null | grep -A 17 'OCSP response:' > $OCSP_RESPONSE_TMP"

	if [ -n "${DEBUG}" ] ; then
	    sed 's/^/[DBG]\ /' "${OCSP_RESPONSE_TMP}"
	fi

	if ! grep -q 'Next Update' "${OCSP_RESPONSE_TMP}" ; then
	    critical "OCSP stapling not enabled"
	else
	    if [ -n "${VERBOSE}" ] ; then
       		echo "  OCSP stapling enabled"
	    fi
	fi	    
	
    fi
    
    # shellcheck disable=SC2086
    SIGNATURE_ALGORITHM="$($OPENSSL "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" -text -noout | grep 'Signature Algorithm' | head -n 1)"

    if [ -n "${DEBUG}" ] ; then
        echo "[DBG] ${SUBJECT}"
        echo "[DBG] CN         = ${CN}"
        echo "[DBG] CA_O       = ${CA_O}"
        echo "[DBG] CA_CN      = ${CA_CN}"
        echo "[DBG] SERIAL     = ${SERIAL}"
	echo "[DBG] FINGERPRINT= ${FINGERPRINT}"
        echo "[DBG] OCSP_URI   = ${OCSP_URI}"
        echo "[DBG] ISSUER_URI = ${ISSUER_URI}"
        echo "[DBG] ${SIGNATURE_ALGORITHM}"
    fi

    if echo "${SIGNATURE_ALGORITHM}" | grep -q "sha1" ; then

        if [ -n "${NOSIGALG}" ] ; then

            if [ -n "${VERBOSE}" ] ; then
                echo "${OPENSSL_COMMAND} Certificate is signed with SHA-1"
            fi

        else

            critical "${OPENSSL_COMMAND} Certificate is signed with SHA-1"

        fi

    fi

    if echo "${SIGNATURE_ALGORITHM}" | grep -qi "md5" ; then

        if [ -n "${NOSIGALG}" ] ; then

            if [ -n "${VERBOSE}" ] ; then
                echo "${OPENSSL_COMMAND} Certificate is signed with MD5"
            fi

        else

            critical "${OPENSSL_COMMAND} Certificate is signed with MD5"

        fi

    fi

    ################################################################################
    # Generate the long output
    if [ -n "${LONG_OUTPUT_ATTR}" ] ; then

        check_attr() {
            ATTR="$1"
            if ! echo "${VALID_ATTRIBUTES}" | grep -q ",${ATTR}," ; then
                unknown "Invalid certificate attribute: ${ATTR}"
            else
		# shellcheck disable=SC2086
                value="$(${OPENSSL} "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" -noout -nameopt utf8,oneline,-esc_msb  -"${ATTR}" | sed -e "s/.*=//")"
                LONG_OUTPUT="${LONG_OUTPUT}\\n${ATTR}: ${value}"
            fi

        }

        # Split on comma
        if [ "${LONG_OUTPUT_ATTR}" = "all" ] ; then
            LONG_OUTPUT_ATTR="${VALID_ATTRIBUTES}"
        fi
        attributes=$( echo ${LONG_OUTPUT_ATTR} | tr ',' "\\n" )
        for attribute in $attributes ; do
            check_attr "${attribute}"
        done

    fi

    ################################################################################
    # Compute for how many days the certificate will be valid
    if [ -n "${DATETYPE}" ]; then

	# shellcheck disable=SC2086
        CERT_END_DATE=$($OPENSSL "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" -noout ${OPENSSL_ENDDATE_OPTION} | sed -e "s/.*=//")

        OLDLANG=$LANG
        LANG=en_US

        if [ -n "${DEBUG}" ] ; then
            echo "[DBG] Date computations: ${DATETYPE}"
        fi

        case "${DATETYPE}" in
            "BSD")
                DAYS_VALID=$(( ( $(${DATEBIN} -jf "%b %d %T %Y %Z" "${CERT_END_DATE}" +%s) - $(${DATEBIN} +%s) ) / 86400 ))
                ;;

            "GNU")
                DAYS_VALID=$(( ( $(${DATEBIN} -d "${CERT_END_DATE}" +%s) - $(${DATEBIN} +%s) ) / 86400 ))
                ;;

            "PERL")
                # Warning: some shell script formatting tools will indent the EOF! (should be at position 0)
                if ! DAYS_VALID=$(perl - "${CERT_END_DATE}" <<-"EOF"
                    use strict;
                    use warnings;
                    use Date::Parse;
                    my $cert_date = str2time( $ARGV[0] );
                    my $days = int (( $cert_date - time ) / 86400 + 0.5);
                    print "$days\n";
EOF
                ) ; then
                    # somethig went wrong with the embedded Perl code: check the indentation of EOF
                    unknown "Error computing the certificate validity with Perl"
                fi
                ;;
        esac

        LANG=$OLDLANG

        if [ -n "${VERBOSE}" ] ; then

            if [ "${DAYS_VALID}" -ge 0 ] ; then
                echo "The certificate will expire in ${DAYS_VALID} day(s)"
            else
                echo "The certificate expired "$((- DAYS_VALID))" day(s) ago"
            fi

        fi
        add_performance_data "days=$DAYS_VALID;${WARNING};${CRITICAL};;"

    fi

    ################################################################################
    # Check the presence of a subjectAlternativeName (required for Chrome)
    
    # shellcheck disable=SC2086
    SUBJECT_ALTERNATIVE_NAME=$($OPENSSL "${OPENSSL_COMMAND}" ${OPENSSL_PARAMS} -in "${CERT}" -text |
           grep --after-context=1 "509v3 Subject Alternative Name:" |
           tail -n 1 |
           sed -e "s/DNS://g" |
           sed -e "s/,//g" |
           sed -e "s/^\\ *//"
        )
    if [ -n "${DEBUG}" ] ; then
        echo "[DBG] subjectAlternativeName = ${SUBJECT_ALTERNATIVE_NAME}"
    fi
    if [ -n "${REQUIRE_SAN}" ] && [ -z "${SUBJECT_ALTERNATIVE_NAME}" ] && [ ${OPENSSL_COMMAND} != "crl" ] ; then
        critical "The certificate for this site does not contain a Subject Alternative Name extension containing a domain name or IP address."
    fi

    ################################################################################
    # Check the CN
    if [ -n "$COMMON_NAME" ] ; then

        ok=""

        if [ -n "${DEBUG}" ] ; then
            echo "[DBG] check CN: ${CN}"
        fi

        # Common name is case insensitive: using grep for comparison (and not 'case' with 'shopt -s nocasematch' as not defined in POSIX

        if echo "${CN}" | grep -q -i "^\\*\\." ; then

            # Match the domain
            if [ -n "${DEBUG}" ] ; then
                echo "[DBG] the common name ${CN} begins with a '*'"
                echo "[DBG] checking if the common name matches ^$(echo "${CN}" | cut -c 3-)\$"
            fi
            if echo "${COMMON_NAME}" | grep -q -i "^$(echo "${CN}" | cut -c 3-)\$" ; then
                if [ -n "${DEBUG}" ] ; then
                    echo "[DBG] the common name ${COMMON_NAME} matches ^$( echo "${CN}" | cut -c 3- )\$"
                fi
                ok="true"

            fi

            # Or the literal with the wildcard
            if [ -n "${DEBUG}" ] ; then
                echo "[DBG] checking if the common name matches ^$(echo "${CN}" | sed -e 's/[.]/[.]/g' -e 's/[*]/[A-Za-z0-9\-]*/' )\$"
            fi
            if echo "${COMMON_NAME}" | grep -q -i "^$(echo "${CN}" | sed -e 's/[.]/[.]/g' -e 's/[*]/[A-Za-z0-9\-]*/' )\$" ; then
                if [ -n "${DEBUG}" ] ; then
                    echo "[DBG] the common name ${COMMON_NAME} matches ^$(echo "${CN}" | sed -e 's/[.]/[.]/g' -e 's/[*]/[A-Za-z0-9\-]*/' )\$"
                fi
                ok="true"
            fi

            # Or if both are exactly the same
            if [ -n "${DEBUG}" ] ; then
                echo "[DBG] checking if the common name matches ^${CN}\$"
            fi
            if echo "${COMMON_NAME}" | grep -q -i "^${CN}\$" ; then
                if [ -n "${DEBUG}" ] ; then
                    echo "[DBG] the common name ${COMMON_NAME} matches ^${CN}\$"
                fi
                ok="true"
            fi

        else

            if echo "${COMMON_NAME}" | grep -q -i "^${CN}$" ; then
                ok="true"
            fi

        fi

        # Check alternate names
        if [ -n "${ALTNAMES}" ] && [ -z "$ok" ]; then

            for cn in ${COMMON_NAME} ; do

                ok=""

                if [ -n "${DEBUG}" ] ; then
                    echo "[DBG] checking altnames against ${cn}"
                fi

                for alt_name in ${SUBJECT_ALTERNATIVE_NAME} ; do

                    if [ -n "${DEBUG}" ] ; then
                        echo "[DBG] check Altname: ${alt_name}"
                    fi

                    if echo "${alt_name}" | grep -q -i "^\\*\\." ; then

                        # Match the domain
                        if [ -n "${DEBUG}" ] ; then
                            echo "[DBG] the altname ${alt_name} begins with a '*'"
                            echo "[DBG] checking if the common name matches ^$(echo "${alt_name}" | cut -c 3-)\$"
                        fi
                        if echo "${cn}" | grep -q -i "^$(echo "${alt_name}" | cut -c 3-)\$" ; then
                            if [ -n "${DEBUG}" ] ; then
                                echo "[DBG] the common name ${cn} matches ^$( echo "${alt_name}" | cut -c 3- )\$"
                            fi
                            ok="true"

                        fi

                        # Or the literal with the wildcard
                        if [ -n "${DEBUG}" ] ; then
                            echo "[DBG] checking if the common name matches ^$(echo "${alt_name}" | sed -e 's/[.]/[.]/g' -e 's/[*]/[A-Za-z0-9\-]*/' )\$"
                        fi
                        if echo "${cn}" | grep -q -i "^$(echo "${alt_name}" | sed -e 's/[.]/[.]/g' -e 's/[*]/[A-Za-z0-9\-]*/' )\$" ; then
                            if [ -n "${DEBUG}" ] ; then
                                echo "[DBG] the common name ${cn} matches ^$(echo "${alt_name}" | sed -e 's/[.]/[.]/g' -e 's/[*]/[A-Za-z0-9\-]*/' )\$"
                            fi
                            ok="true"
                        fi

                        # Or if both are exactly the same
                        if [ -n "${DEBUG}" ] ; then
                            echo "[DBG] checking if the common name matches ^${alt_name}\$"
                        fi
                        if echo "${cn}" | grep -q -i "^${alt_name}\$" ; then
                            if [ -n "${DEBUG}" ] ; then
                                echo "[DBG] the common name ${cn} matches ^${alt_name}\$"
                            fi
                            ok="true"
                        fi

                    else

                        if echo "${cn}" | grep -q -i "^${alt_name}$" ; then
                            ok="true"
                        fi

                    fi

                    if [ -n "$ok" ] ; then
                        #fail=$cn
                        break;
                    fi

                done

                if [ -z "$ok" ] ; then
                    fail=$cn
                    break;
                fi

            done

        fi

        if [ -n "$fail" ] ; then
           critical "invalid CN ('$CN' does not match '$fail')"
        fi

        if [ -z "$ok" ] ; then
            critical "invalid CN ('$CN' does not match '$COMMON_NAME')"
        fi

        if [ -n "${DEBUG}" ] ; then
            echo "[DBG] CN check finished"
        fi

    fi

    ################################################################################
    # Check the issuer
    if [ -n "${ISSUER}" ] ; then

        if [ -n "${DEBUG}" ] ; then
            echo "[DBG] check ISSUER: ${ISSUER}"
        fi

        ok=""
        CA_ISSUER_MATCHED=""

        if echo "${CA_CN}" | grep -q "^${ISSUER}\$" ; then
            ok="true"
            CA_ISSUER_MATCHED="${CA_CN}"
        fi

        if echo "${CA_O}" | grep -q "^${ISSUER}\$" ; then
            ok="true"
            CA_ISSUER_MATCHED="${CA_O}"
        fi

        if [ -z "${ok}" ] ; then
            critical "invalid CA ('${ISSUER}' does not match '${CA_O}' or '${CA_CN}')"
        fi

    else

        CA_ISSUER_MATCHED="${CA_CN}"

    fi

    ################################################################################
    # Check the serial number
    if [ -n "${SERIAL_LOCK}" ] ; then

        ok=""

        if echo "${SERIAL}" | grep -q "^${SERIAL_LOCK}\$" ; then
            ok="true"
        fi

        if [ -z "$ok" ] ; then
            critical "invalid serial number ('${SERIAL}' does not match '${SERIAL_LOCK}')"
        fi

    fi
    ################################################################################
    # Check the Fingerprint
    if [ -n "${FINGERPRINT_LOCK}" ] ; then

        ok=""

        if echo "${FINGERPRINT}" | grep -q "^${FINGERPRINT_LOCK}\$" ; then
            ok="true"
        fi

        if [ -z "$ok" ] ; then
            critical "invalid SHA1 Fingerprint ('${FINGERPRINT}' does not match '${FINGERPRINT_LOCK}')"
        fi

    fi

    ################################################################################
    # Check the validity
    if [ -z "${NOEXP}" ] ; then

        if [ -n "${DEBUG}" ] ; then
            echo "[DBG] Checking expiration date"
        fi

        if [ ${OPENSSL_COMMAND} = "x509" ]; then
            # x509 certificates (default)

            # We always check expired certificates
            if ! $OPENSSL x509 -in "${CERT}" -noout -checkend 0 > /dev/null ; then
                critical "${OPENSSL_COMMAND} certificate is expired (was valid until $DATE)"
            fi

            if [ -n "${CRITICAL}" ] ; then

                if [ -n "${DEBUG}" ] ; then
                    echo "[DBG] executing: $OPENSSL x509 -in ${CERT} -noout -checkend $(( CRITICAL * 86400 ))"
                fi

                if ! $OPENSSL x509 -in "${CERT}" -noout -checkend $(( CRITICAL * 86400 )) > /dev/null ; then
                    critical "${OPENSSL_COMMAND} certificate will expire in ${DAYS_VALID} day(s) on $DATE"
                fi

            fi

            if [ -n "${WARNING}" ] ; then

                if [ -n "${DEBUG}" ] ; then
                    echo "[DBG] executing: $OPENSSL x509 -in ${CERT} -noout -checkend $(( WARNING * 86400 ))"
                fi

                if ! $OPENSSL x509 -in "${CERT}" -noout -checkend $(( WARNING * 86400 )) > /dev/null ; then
                    warning "${OPENSSL_COMMAND} certificate will expire in ${DAYS_VALID} day(s) on $DATE"
                fi

            fi
        elif [ ${OPENSSL_COMMAND} = "crl" ]; then
            # CRL certificates

            # We always check expired certificates
            if [ "${DAYS_VALID}" -lt 1 ] ; then
                critical "${OPENSSL_COMMAND} certificate is expired (was valid until $DATE)"
            fi

            if [ -n "${CRITICAL}" ] ; then
                if [ "${DAYS_VALID}" -lt "${CRITICAL}" ] ; then
                    critical "${OPENSSL_COMMAND} certificate will expire in ${DAYS_VALID} day(s) on $DATE"
                fi

            fi

            if [ -n "${WARNING}" ] ; then
                if [ "${DAYS_VALID}" -lt "${WARNING}" ] ; then
                    warning "${OPENSSL_COMMAND} certificate will expire in ${DAYS_VALID} day(s) on $DATE"
                fi

            fi
        fi

    fi

    ################################################################################
    # Check SSL Labs
    if [ -n "${SSL_LAB_ASSESSMENT}" ] ; then

        if [ -n "${VERBOSE}" ] ; then
            echo "Checking SSL Labs assessment"
        fi

        while true; do

            if [ -n "${DEBUG}" ] ; then
                echo "[DBG] executing ${CURL_BIN} --silent \"https://api.ssllabs.com/api/v2/analyze?host=${HOST}${IGNORE_SSL_LABS_CACHE}\""
            fi	    
	    
            JSON="$(${CURL_BIN} --silent "https://api.ssllabs.com/api/v2/analyze?host=${HOST}${IGNORE_SSL_LABS_CACHE}")"
            CURL_RETURN_CODE=$?

            if [ ${CURL_RETURN_CODE} -ne 0 ] ; then

                if [ -n "${DEBUG}" ] ; then
                    echo "[DBG] curl returned ${CURL_RETURN_CODE}: ${CURL_BIN} --silent \"https://api.ssllabs.com/api/v2/analyze?host=${HOST}${IGNORE_SSL_LABS_CACHE}\""
                fi

                unknown "Error checking SSL Labs: curl returned ${CURL_RETURN_CODE}, see 'man curl' for details"

            fi

            JSON="$(printf '%s' "${JSON}" | tr '\n' ' ' )"

            if [ -n "${DEBUG}" ] ; then
                echo "[DBG] Checking SSL Labs: ${CURL_BIN} --silent \"https://api.ssllabs.com/api/v2/analyze?host=${HOST}\""
                echo "[DBG] SSL Labs JSON: ${JSON}"
            fi

            # We clear the cache only on the first run
            IGNORE_SSL_LABS_CACHE=""

            SSL_LABS_HOST_STATUS=$(echo "${JSON}" \
                | sed 's/.*"status":[ ]*"\([^"]*\)".*/\1/')

            if [ -n "${DEBUG}" ] ; then
                echo "[DBG] SSL Labs status: ${SSL_LABS_HOST_STATUS}"
            fi

            case "${SSL_LABS_HOST_STATUS}" in
                'ERROR')
                    SSL_LABS_STATUS_MESSAGE=$(echo "${JSON}" \
                        | sed 's/.*"statusMessage":[ ]*"\([^"]*\)".*/\1/')
                    critical "Error checking SSL Labs: ${SSL_LABS_STATUS_MESSAGE}"
                    ;;
                'READY')
                    if ! echo "${JSON}" | grep -q "grade" ; then

                        # Something went wrong
                        SSL_LABS_STATUS_MESSAGE=$(echo "${JSON}" \
                            | sed 's/.*"statusMessage":[ ]*"\([^"]*\)".*/\1/')
                        critical "SSL Labs error: ${SSL_LABS_STATUS_MESSAGE}"

                    else

                        SSL_LABS_HOST_GRADE=$(echo "${JSON}" \
                            | sed 's/.*"grade":[ ]*"\([^"]*\)".*/\1/')

                        if [ -n "${DEBUG}" ] ; then
                            echo "[DBG] SSL Labs grade: ${SSL_LABS_HOST_GRADE}"
                        fi

                        if [ -n "${VERBOSE}" ] ; then
                            echo "SSL Labs grade: ${SSL_LABS_HOST_GRADE}"
                        fi

                        convert_ssl_lab_grade "${SSL_LABS_HOST_GRADE}"
                        SSL_LABS_HOST_GRADE_NUMERIC="${NUMERIC_SSL_LAB_GRADE}"

                        add_performance_data "ssllabs=${SSL_LABS_HOST_GRADE_NUMERIC}%;;${SSL_LAB_ASSESSMENT_NUMERIC}"

                        # Check the grade
                        if [ "${SSL_LABS_HOST_GRADE_NUMERIC}" -lt "${SSL_LAB_ASSESSMENT_NUMERIC}" ] ; then
                            critical "SSL Labs grade is ${SSL_LABS_HOST_GRADE} (instead of ${SSL_LAB_ASSESSMENT})"
                        fi

                        if [ -n "${DEBUG}" ] ; then
                            echo "[DBG] SSL Labs grade (converted): ${SSL_LABS_HOST_GRADE_NUMERIC}"
                        fi

                        # We have a result: exit
                        break

                    fi
                    ;;
                'IN_PROGRESS')
                    # Data not yet available: warn and continue
                    if [ -n "${VERBOSE}" ] ; then
                        echo "Warning: no cached data by SSL Labs, check initiated"
                    fi
                    ;;
                'DNS')
                    if [ -n "${VERBOSE}" ] ; then
                        echo 'SSL Labs cannot resolve the domain name'
                    fi
                    ;;
                *)
                    # Try to extract a message
                    SSL_LABS_ERROR_MESSAGE=$(echo "${JSON}" \
                        | sed 's/.*"message":[ ]*"\([^"]*\)".*/\1/')

                    if [ -z "${SSL_LABS_ERROR_MESSAGE}" ] ; then
                        SSL_LABS_ERROR_MESSAGE="${JSON}"
                    fi

                    critical "Cannot check status on SSL Labs: ${SSL_LABS_ERROR_MESSAGE}"
            esac

            WAIT_TIME=60
            if [ -n "${VERBOSE}" ] ; then
                echo "Waiting ${WAIT_TIME} seconds"
            fi

            sleep "${WAIT_TIME}"

        done

    fi

    ################################################################################
    # Check revocation via OCSP
    if [ -n "${OCSP}" ]; then

        if [ -n "${DEBUG}" ] ; then
            echo "[DBG] Checking revokation via OCSP"
        fi

        ISSUER_HASH="$($OPENSSL x509 -in "${CERT}" -noout -issuer_hash)"

        if [ -z "${ISSUER_HASH}" ] ; then
            unknown 'unable to find issuer certificate hash.'
        fi

        if [ -n "${ISSUER_CERT_CACHE}" ] ; then

            if [ -r "${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt" ]; then

                if [ -n "${DEBUG}" ] ; then
                    echo "[DBG] Found cached Issuer Certificate: ${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt"
                fi
                ISSUER_CERT="${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt"

            else

                if [ -n "${DEBUG}" ] ; then
                    echo "[DBG] Not found cached Issuer Certificate: ${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt"
                fi

            fi

        fi

        if [ -z "${ISSUER_CERT}" ] ; then

            if [ -n "${DEBUG}" ] ; then
                echo "[DBG] OCSP: fetching issuer certificate ${ISSUER_URI} to ${ISSUER_CERT_TMP}"
            fi

            exec_with_timeout "$TIMEOUT" "${CURL_BIN} --silent --location ${ISSUER_URI} > ${ISSUER_CERT_TMP}"

            if [ -n "${DEBUG}" ] ; then

                echo "[DBG] OCSP: issuer certificate type: $(${FILE_BIN} "${ISSUER_CERT_TMP}" | sed 's/.*://' )"

            fi

            # check the result
            if ! "${FILE_BIN}" "${ISSUER_CERT_TMP}" | grep -E -q ': (ASCII|PEM)' ; then

                if "${FILE_BIN}" "${ISSUER_CERT_TMP}" | grep -q ': data' ; then

                    if [ -n "${DEBUG}" ] ; then
                        echo "[DBG] OCSP: converting issuer certificate from DER to PEM"
                    fi

                    cp "${ISSUER_CERT_TMP}" "${ISSUER_CERT_TMP2}"

                    $OPENSSL x509 -inform DER -outform PEM -in "${ISSUER_CERT_TMP2}" -out "${ISSUER_CERT_TMP}"

                else

                    unknown "Unable to fetch OCSP issuer certificate."

                fi

            fi

            if [ -n "${DEBUG}" ] ; then

                # remove trailing /
                FILE_NAME=${ISSUER_URI%/}

                # remove everything up to the last slash
                FILE_NAME=${FILE_NAME##*/}

                echo "[DBG] OCSP: storing a copy of the retrieved issuer certificate to ${FILE_NAME}"

                cp "${ISSUER_CERT_TMP}" "${FILE_NAME}"
            fi

            if [ -n "${ISSUER_CERT_CACHE}" ] ; then
                if [ ! -w "${ISSUER_CERT_CACHE}" ]; then

                    unknown "Issuer certificates cache ${ISSUER_CERT_CACHE} is not writeable!"

                fi

                if [ -n "${DEBUG}" ] ; then
                    echo "[DBG] Storing Issuer Certificate to cache: ${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt"
                fi

                cp "${ISSUER_CERT_TMP}" "${ISSUER_CERT_CACHE}/${ISSUER_HASH}.crt"

            fi

            ISSUER_CERT=${ISSUER_CERT_TMP}

        fi
        OCSP_HOST="$(echo "${OCSP_URI}" | sed -e "s@.*//\\([^/]\\+\\)\\(/.*\\)\\?\$@\\1@g" | sed 's/^http:\/\///' | sed 's/\/.*//' )"

        if [ -n "${DEBUG}" ] ; then
            echo "[DBG] OCSP: host = ${OCSP_HOST}"
        fi

        # check if -header is supported
        OCSP_HEADER=""

        # ocsp -header is supported in OpenSSL versions from 1.0.0, but not documented until 1.1.0
        # so we check if the major version is greater than 0
        if "${OPENSSL}" version | grep -q '^LibreSSL' || [ "$( ${OPENSSL} version | sed -e 's/OpenSSL \([0-9]\).*/\1/g' )" -gt 0 ] ; then

            if [ -n "${DEBUG}" ] ; then
                echo "[DBG] openssl ocsp supports the -header option"
            fi

            # the -header option was first accepting key and value separated by space. The newer versions are using key=value
            KEYVALUE=""
            if openssl ocsp -help 2>&1 | grep header | grep -q 'key=value' ; then
                if [ -n "${DEBUG}" ] ; then
                    echo "[DBG] openssl ocsp -header requires 'key=value'"
                fi
                KEYVALUE=1
            else
                if [ -n "${DEBUG}" ] ; then
                    echo "[DBG] openssl ocsp -header requires 'key value'"
                fi
            fi

            # http_proxy is sometimes lower- and sometimes uppercase. Programs usually check both
            # shellcheck disable=SC2154
            if [ -n "${http_proxy}" ] ; then
                HTTP_PROXY="${http_proxy}"
            fi

            if [ -n "${HTTP_PROXY:-}" ] ; then

                if [ -n "${KEYVALUE}" ] ; then
                    if [ -n "${DEBUG}" ] ; then
                        echo "[DBG] executing $OPENSSL ocsp -no_nonce -issuer ${ISSUER_CERT} -cert ${CERT} -host ${HTTP_PROXY#*://} -path ${OCSP_URI} -header HOST=${OCSP_HOST}"
                    fi
                    OCSP_RESP="$($OPENSSL ocsp -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT}" -host "${HTTP_PROXY#*://}" -path "${OCSP_URI}" -header HOST="${OCSP_HOST}" 2>&1 )"
                else
                    if [ -n "${DEBUG}" ] ; then
                        echo "[DBG] executing $OPENSSL ocsp -no_nonce -issuer ${ISSUER_CERT} -cert ${CERT} -host ${HTTP_PROXY#*://} -path ${OCSP_URI} -header HOST ${OCSP_HOST}"
                    fi
                    OCSP_RESP="$($OPENSSL ocsp -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT}" -host "${HTTP_PROXY#*://}" -path "${OCSP_URI}" -header HOST "${OCSP_HOST}" 2>&1 )"
                fi

            else

                if [ -n "${KEYVALUE}" ] ; then
                    if [ -n "${DEBUG}" ] ; then
                        echo "[DBG] executing $OPENSSL ocsp -no_nonce -issuer ${ISSUER_CERT} -cert ${CERT}  -url ${OCSP_URI} ${OCSP_HEADER} -header HOST=${OCSP_HOST}"
                    fi
                        OCSP_RESP="$($OPENSSL ocsp -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT}" -url "${OCSP_URI}" -header "HOST=${OCSP_HOST}" 2>&1 )"
                else
                    if [ -n "${DEBUG}" ] ; then
                    echo "[DBG] executing $OPENSSL ocsp -no_nonce -issuer ${ISSUER_CERT} -cert ${CERT}  -url ${OCSP_URI} ${OCSP_HEADER} -header HOST ${OCSP_HOST}"
                    fi
                    OCSP_RESP="$($OPENSSL ocsp -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT}" -url "${OCSP_URI}" -header HOST "${OCSP_HOST}" 2>&1 )"
                fi

            fi

            if [ -n "${DEBUG}" ] ; then
                echo "${OCSP_RESP}" | sed 's/^/[DBG] OCSP: response = /'
            fi

            if echo "${OCSP_RESP}" | grep -qi "revoked" ; then
                critical "certificate is revoked"
            elif ! echo "${OCSP_RESP}" | grep -qi "good" ; then

                if [ -n "${HTTP_PROXY:-}" ] ; then
                    OCSP_RESP="$($OPENSSL ocsp -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT}" -host "${HTTP_PROXY#*://}" -path "${OCSP_URI}" "${OCSP_HEADER}" 2>&1 )"
                else
                    OCSP_RESP="$($OPENSSL ocsp -no_nonce -issuer "${ISSUER_CERT}" -cert "${CERT}" -url "${OCSP_URI}" "${OCSP_HEADER}" 2>&1 )"
                fi
                critical "${OCSP_RESP}"

            fi

        else

            if [ -n "${VERBOSE}" ] ; then
                echo "openssl ocsp does not support the -header option: disabling OCSP checks"
            fi

        fi

    fi

    ################################################################################
    # Check the organization
    if [ -n "$ORGANIZATION" ] ; then

        ORG=$($OPENSSL x509 -in "${CERT}" -subject -noout | sed -e "s/.*\\/O=//" -e "s/\\/.*//")

        if ! echo "$ORG" | grep -q "^$ORGANIZATION" ; then
            critical "invalid organization ('$ORGANIZATION' does not match '$ORG')"
        fi

    fi

    ################################################################################
    # Check the organization
    if [ -n "$ADDR" ] ; then

        EMAIL=$($OPENSSL x509 -in "${CERT}" -email -noout)

        if [ -n "${VERBOSE}" ] ; then
            echo "checking email (${ADDR}): ${EMAIL}"
        fi

        if [ -z "${EMAIL}" ] ; then
            critical "the certificate does not contain an email address"
        fi

        if ! echo "$EMAIL" | grep -q "^$ADDR" ; then
            critical "invalid email ($ADDR does not match $EMAIL)"
        fi

    fi

    ################################################################################
    # Check if the certificate was verified
    if [ -z "${NOAUTH}" ] && grep -q '^verify\ error:' "${ERROR}" ; then

        if grep -q '^verify\ error:num=[0-9][0-9]*:self\ signed\ certificate' "${ERROR}" ; then

            if [ -z "${SELFSIGNED}" ] ; then
                critical "Cannot verify certificate, self signed certificate"
            else
                SELFSIGNEDCERT="self signed "
            fi

        else

            if [ -n "${DEBUG}" ] ; then
                sed 's/^/[DBG] Error: /' "${ERROR}"
            fi

            # Process errors
            details=$( grep  '^verify\ error:' "${ERROR}" | sed 's/verify\ error:num=[0-9]*://' | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/, /g' )
            critical "Cannot verify certificate: ${details}"

        fi

    fi
    
    ################################################################################
    # If we get this far, assume all is well. :)

    # If --altnames was specified or if the certificate is wildcard,
    # then we show the specified CN in addition to the certificate CN
    CHECKEDNAMES=""
    if [ -n "${ALTNAMES}" ] && [ -n "${COMMON_NAME}" ] && [ "${CN}" != "${COMMON_NAME}" ]; then
        CHECKEDNAMES="(${COMMON_NAME}) "
    elif [ -n "${COMMON_NAME}" ] && echo "${CN}" | grep -q -i "^\\*\\." ; then
        CHECKEDNAMES="(${COMMON_NAME}) "
    fi

    if [ -n "${DAYS_VALID}" ] ; then
        # nicer formatting
        if [ "${DAYS_VALID}" -gt 1 ] ; then
            DAYS_VALID=" (expires in ${DAYS_VALID} days)"
        elif [ "${DAYS_VALID}" -eq 1 ] ; then
            DAYS_VALID=" (expires tomorrow)"
        elif [ "${DAYS_VALID}" -eq 0 ] ; then
            DAYS_VALID=" (expires today)"
        elif [ "${DAYS_VALID}" -eq -1 ] ; then
            DAYS_VALID=" (expired yesterday)"
        else
            DAYS_VALID=" (expired ${DAYS_VALID} days ago)"
        fi
    fi

    if [ -n "${SSL_LABS_HOST_GRADE}" ] ; then
        SSL_LABS_HOST_GRADE=", SSL Labs grade: ${SSL_LABS_HOST_GRADE}"
    fi

    if [ -z "${CN}" ]; then
        DISPLAY_CN=""
    else
        DISPLAY_CN="'${CN}' "
    fi

    if [ -z "$FORMAT" ]; then
        if [ -n "${TERSE}" ]; then
            FORMAT="%SHORTNAME% OK %CN% %DAYS_VALID%"
        else
            FORMAT="%SHORTNAME% OK - %OPENSSL_COMMAND% %SELFSIGNEDCERT%certificate %DISPLAY_CN%%CHECKEDNAMES%from '%CA_ISSUER_MATCHED%' valid until %DATE%%DAYS_VALID%%SSL_LABS_HOST_GRADE%"
        fi
    fi

    if [ -n "${TERSE}" ]; then
        EXTRA_OUTPUT="${PERFORMANCE_DATA}"
    else
        EXTRA_OUTPUT="${PERFORMANCE_DATA}${LONG_OUTPUT}"
    fi

    echo "${FORMAT}${EXTRA_OUTPUT}" | sed \
        -e "$( var_for_sed CA_ISSUER_MATCHED "${CA_ISSUER_MATCHED}" )" \
        -e "$( var_for_sed CHECKEDNAMES "${CHECKEDNAMES}" )" \
        -e "$( var_for_sed CN "${CN}" )" \
        -e "$( var_for_sed DATE "${DATE}" )" \
        -e "$( var_for_sed DAYS_VALID "${DAYS_VALID}" )" \
        -e "$( var_for_sed DISPLAY_CN "${DISPLAY_CN}" )" \
        -e "$( var_for_sed OPENSSL_COMMAND "${OPENSSL_COMMAND}" )" \
        -e "$( var_for_sed SELFSIGNEDCERT "${SELFSIGNEDCERT}" )" \
        -e "$( var_for_sed SHORTNAME "${SHORTNAME}" )" \
        -e "$( var_for_sed SSL_LABS_HOST_GRADE "${SSL_LABS_HOST_GRADE}" )"

    remove_temporary_files

    exit 0

}

if [ -z "${SOURCE_ONLY}" ]; then
    main "${@}"
fi
