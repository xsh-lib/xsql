#? Description:
#?   A pseudo SQL interpreter for Bash.
#?   Using UNIX text files instead of RDBMS tables as the data store.
#?   By default, the field delimiter for input is whitespace ' ',
#?   the field delimiter for output is '\t'.
#?   The row delimiter is 'new line' for both input and output.
#?
#? Usage:
#?   @query [OPTIONS] SELECT-CLAUSE FROM-CLAUSE \
#?       [WHERE-CLAUSE]
#?
#? Options:
#?   [OPTIONS]
#?     [-F] FS
#?
#?     Specify the FS used internally, default is ''.
#?
#?     [-I] FS
#?
#?     Specify the input FS, will be used to process table,
#?     default is whitespace ' '.
#?
#?     [-O] FS
#?
#?     Specify the output FS, will be used to output result,
#?     default is '\t'.
#?
#?     [-H]
#?
#?     Show the table header in the result output if specified.
#?
#? Return:
#?   0: succeed
#?   255: error
#?   100: 0 row selected
#?
#? Export:
#?   XSQL_QUERY_FIELDS:               [Array] Field list in the table
#?   XSQL_QUERY_FIELDS_*_ROWS:        [Array] Rows in the table by field
#?   XSQL_QUERY_SELECTED_ROW_COUNT:   Row count returned
#?   XSQL_QUERY_SELECTED_ROW_INDICES: [Array] Row indices returned
#?
#? Output:
#?   Query result without header.
#?
#? Examples:
#?   $ cat A
#?   a b c
#?   1 4 7
#?   2 5 8
#?   3 6 9
#?
#?   $ @query select a,b,c from A where a = 1 or b = 5
#?   1	4	7
#?   2	5	8
#?
#? Explanation:
#?
#?   +--------+-----------+-----------------+----------------+----------------+
#?   | Clause | Character | Escape Required | Escape Example | Case-sensitive |
#?   +========+===========+=================+================+================+
#?   | SELECT | ,         | No              | -              | -              |
#?   +--------+-----------+-----------------+----------------+----------------+
#?   | WHERE  | =         | No              | -              | -              |
#?   |        +-----------+-----------------+----------------+----------------+
#?   |        | !=        | No              | -              | -              |
#?   |        +-----------+-----------------+----------------+----------------+
#?   |        | >         | Yes             | \>             | -              |
#?   |        +-----------+-----------------+----------------+----------------+
#?   |        | <         | Yes             | \<             | -              |
#?   |        +-----------+-----------------+----------------+----------------+
#?   |        | -eq       | No              | -              | Yes            |
#?   |        +-----------+-----------------+----------------+----------------+
#?   |        | -ne       | No              | -              | Yes            |
#?   |        +-----------+-----------------+----------------+----------------+
#?   |        | -gt       | No              | -              | Yes            |
#?   |        +-----------+-----------------+----------------+----------------+
#?   |        | -ge       | No              | -              | Yes            |
#?   |        +-----------+-----------------+----------------+----------------+
#?   |        | -lt       | No              | -              | Yes            |
#?   |        +-----------+-----------------+----------------+----------------+
#?   |        | -le       | No              | -              | Yes            |
#?   |        +-----------+-----------------+----------------+----------------+
#?   |        | and       | No              | -              | Yes            |
#?   |        +-----------+-----------------+----------------+----------------+
#?   |        | or        | No              | -              | Yes            |
#?   |        +-----------+-----------------+----------------+----------------+
#?   |        | (         | Yes             | \(             | -              |
#?   |        +-----------+-----------------+----------------+----------------+
#?   |        | )         | Yes             | \)             | -              |
#?   +--------+-----------+-----------------+----------------+----------------+
#?
#? @xsh imports /csv/parser /int/set/eval /array/search xsql/query/parser
#?
function query () {

    #? Special Variables
    #?
    #? +---------------------------------+--------+-------------------+------------+--------+
    #? | Special Variables               | Type   | Setter            | Declarer   | Scope  |
    #? +=================================+========+===================+============+========+
    #? | XSQL_QUERY_FS                   | String | xsql/query        | xsql/query | xsh    |
    #? +---------------------------------+--------+-------------------+------------+--------+
    #? | XSQL_QUERY_IFS                  | String | xsql/query        | xsql/query | xsh    |
    #? +---------------------------------+--------+-------------------+------------+--------+
    #? | XSQL_QUERY_OFS                  | String | xsql/query        | xsql/query | xsh    |
    #? +---------------------------------+--------+-------------------+------------+--------+
    #? | XSQL_QUERY_SELECTED_ROW_COUNT   | String | xsql/query        | None       | Global |
    #? +---------------------------------+--------+-------------------+------------+--------+
    #? | XSQL_QUERY_SELECTED_ROW_INDICES | Array  | xsql/query        | None       | Global |
    #? +---------------------------------+--------+-------------------+------------+--------+
    #? | XSQL_QUERY_SELECTED_FIELDS      | Array  | xsql/query/parser | xsql/query | xsh    |
    #? +---------------------------------+--------+-------------------+------------+--------+
    #? | XSQL_QUERY_TABLE                | String | xsql/query/parser | xsql/query | xsh    |
    #? +---------------------------------+--------+-------------------+------------+--------+
    #? | XSQL_QUERY_WHERE                | String | xsql/query/parser | xsql/query | xsh    |
    #? +---------------------------------+--------+-------------------+------------+--------+
    #? | XSQL_QUERY_FIELDS               | Array  | /csv/parser       | None       | Global |
    #? +---------------------------------+--------+-------------------+------------+--------+
    #? | XSQL_QUERY_FIELDS_*_ROWS        | Array  | /csv/parser       | None       | Global |
    #? +---------------------------------+--------+-------------------+------------+--------+
    #? | XSQL_QUERY_NR                   | String | /csv/parser       | xsql/query | xsh    |
    #? +---------------------------------+--------+-------------------+------------+--------+
    #?


    # shellcheck disable=SC2034
    XSQL_QUERY_FIELDS=()
    XSQL_QUERY_SELECTED_ROW_COUNT=0
    XSQL_QUERY_SELECTED_ROW_INDICES=()

    # Set default Field Separator (FS)
    declare XSQL_QUERY_FS=''     # Internal FS
    declare XSQL_QUERY_IFS=$' '     # Input FS
    declare XSQL_QUERY_OFS=$'\t'    # Output FS

    declare OPTIND OPTARG opt
    declare header=0

    while getopts F:I:O:H opt; do
        case $opt in
            F)
                # shellcheck disable=SC2034
                XSQL_QUERY_FS=$OPTARG
                ;;
            I)
                XSQL_QUERY_IFS=$OPTARG
                ;;
            O)
                XSQL_QUERY_OFS=$OPTARG
                ;;
            H)
                header=1
                ;;
            *)
                break
                ;;
        esac
    done
    shift $((OPTIND - 1))

    declare RESERVED_KEYWORDS OPERATORS

    # shellcheck disable=SC2034
    RESERVED_KEYWORDS=(
        "from"
        "where"
        "and"
        "or"
    )

    # shellcheck disable=SC2034
    OPERATORS=(
        [1]="="
        [2]="!="
        [3]=">"
        [4]="<"
        [5]="-eq"
        [6]="-ne"
        [7]="-gt"
        [8]="-ge"
        [9]="-lt"
        [10]="-le"
    )

    # Parsing SQL

    declare XSQL_QUERY_SELECTED_FIELDS XSQL_QUERY_TABLE XSQL_QUERY_WHERE  # set by xsql-query-parser
    xsql-query-parser "$@" || return

    if [[ ! -f $XSQL_QUERY_TABLE ]]; then
        return 255
    fi

    # Parsing table data into array

    declare XSQL_QUERY_NR  # set by x-csv-parser
    x-csv-parser -I "$XSQL_QUERY_IFS" -e -a -p 'XSQL_QUERY_' "$XSQL_QUERY_TABLE"

    # Process where clause

    if [[ ${#XSQL_QUERY_WHERE[@]} -gt 0 ]]; then

        # Process predicates

        declare candidate_set=()
        declare s_field  # search field
        declare s_operator  # search operator

        declare i=1 expr
        for expr in "${XSQL_QUERY_WHERE[@]}"; do
            case $expr in
                '('|')')
                    candidate_set+=( "$expr" )
                    ;;
                *)
                    case $((i % 4)) in
                        1)  # key
                            s_field=$expr
                            ;;
                        2)  # operator
                            s_operator=$expr
                            ;;
                        3)  # value
                            candidate_set+=(
                                "$(x-array-search -o "$s_operator" "XSQL_QUERY_FIELDS_${s_field}_ROWS" "$expr" 2>/dev/null)"
                            )
                            ;;
                        0)  # and/or
                            case $expr in
                                and)
                                    candidate_set+=( '&' )
                                    ;;
                                or)
                                    candidate_set+=( '|' )
                                    ;;
                            esac
                            ;;
                    esac
                    i=$((i + 1))
                    ;;
            esac
        done
        # Calculate candidate sets expression
        # shellcheck disable=SC2207
        XSQL_QUERY_SELECTED_ROW_INDICES=( $(x-int-set-eval "${candidate_set[@]}") )
        if [[ ${XSQL_QUERY_SELECTED_ROW_INDICES[0]} -eq 0 ]]; then
            unset 'XSQL_QUERY_SELECTED_ROW_INDICES[0]'
        fi
    else
        # shellcheck disable=SC2207
        XSQL_QUERY_SELECTED_ROW_INDICES=( $(seq -s ' ' 1 "$((XSQL_QUERY_NR - 1))") )
    fi

    # Process row count

    XSQL_QUERY_SELECTED_ROW_COUNT=${#XSQL_QUERY_SELECTED_ROW_INDICES[@]}
    if [[ $XSQL_QUERY_SELECTED_ROW_COUNT -eq 0 ]]; then
        # No rows returned
        return 100
    fi

    # Process table header

    declare -a output_row_indices
    if [[ $header -eq 1 ]]; then
        # Add table header
        output_row_indices=( 0 )
    fi
    output_row_indices+=( "${XSQL_QUERY_SELECTED_ROW_INDICES[@]}" )

    # Build result record set

    declare row_index
    for row_index in "${output_row_indices[@]}"; do
        declare i=0 qf_name
        for qf_name in "${XSQL_QUERY_SELECTED_FIELDS[@]}"; do
            if [[ $i -gt 0 ]]; then
                printf "%s" "$XSQL_QUERY_OFS"
            fi
            declare varname="XSQL_QUERY_FIELDS_${qf_name}_ROWS[$row_index]"
            printf "%s" "${!varname}"
            i=$((i + 1))
        done
        echo
    done

    return
}
