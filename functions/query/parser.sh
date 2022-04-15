#? Description:
#?   Parse SQL expression and export the parsed into variables.
#?
#? Usage:
#?   @parser SQL
#?
#? Return:
#?   0: succeed
#?   255: error
#?
#? Export:
#?   XSQL_QUERY_SELECTED_FIELDS
#?   XSQL_QUERY_TABLE
#?   XSQL_QUERY_WHERE
#?
#? Output:
#?   Nothing.
#?
#? Example:
#?   $ @parser select f1,f2 from A where f1 = x; set | grep ^XSQL_QUERY_
#?   XSQL_QUERY_SELECTED_FIELDS=([0]="f1" [1]="f2")
#?   XSQL_QUERY_TABLE=A
#?   XSQL_QUERY_WHERE=([0]="f1" [1]="=" [2]="x")
#?
#? @xsh imports /string/lower
#?
function parser () {
    declare clause
    declare -a fields

    XSQL_QUERY_SELECTED_FIELDS=()
    XSQL_QUERY_TABLE=
    XSQL_QUERY_WHERE=()

    while [[ $# -gt 0 ]]; do
        case $(x-string-lower "$1") in
            'select')
                clause="SELECT"
                ;;
            'from')
                clause="FROM"
                ;;
            'where')
                clause="WHERE"
                ;;
            *)
                case $clause in
                    'SELECT')
                        # parse the field list into array
                        IFS=$', ' read -r -a fields <<< "$1"
                        XSQL_QUERY_SELECTED_FIELDS+=( "${fields[@]}" )
                        ;;
                    'FROM')
                        XSQL_QUERY_TABLE=$1
                        ;;
                    'WHERE')
                        XSQL_QUERY_WHERE+=( "$1" )
                        ;;
                    *)
                        return 255
                        ;;
                esac
                ;;
        esac
        shift
    done

    if [[ -z ${XSQL_QUERY_SELECTED_FIELDS[*]} || -z $XSQL_QUERY_TABLE ]]; then
        return 255
    else
        export XSQL_QUERY_SELECTED_FIELDS XSQL_QUERY_TABLE XSQL_QUERY_WHERE
    fi
}
