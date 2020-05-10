#!/usr/bin/env zsh
# nano ~/.config/fish/config.fish
# alias al="sh ~/GitHub/my-macos-build/al/al.sh"

CODA=250

# utility functions
set_output_path() {
  OUTPUT_DIR=$(dirname $0)
  OUTPUT_FILE_NAME=$1
  OUTPUT_PATH="$OUTPUT_DIR/$OUTPUT_FILE_NAME"
  echo $OUTPUT_PATH
}

# output functions
write_food_month() {
  OUTPUT_FILE_FOOD_MONTH=$(set_output_path "temp/food_$(date +"%Y%m").month")
  PRICE=$1
  SUM_FOOD_MONTH=$(cat $OUTPUT_FILE_FOOD_MONTH)
  SUM_FOOD_MONTH=$(expr $SUM_FOOD_MONTH + $PRICE)
  echo $SUM_FOOD_MONTH >$OUTPUT_FILE_FOOD_MONTH
}

write_necessary_month() {
  OUTPUT_FILE_NECESSARY_MONTH=$(set_output_path "temp/necessary_$(date +"%Y%m").month")
  PRICE=$1
  SUM_NECESSARY_MONTH=$(cat $OUTPUT_FILE_NECESSARY_MONTH)
  SUM_NECESSARY_MONTH=$(expr $SUM_NECESSARY_MONTH + $PRICE)
  echo $SUM_NECESSARY_MONTH >$OUTPUT_FILE_NECESSARY_MONTH
}

write_other_month() {
  OUTPUT_FILE_OTHER_MONTH=$(set_output_path "temp/other_$(date +"%Y%m").month")
  PRICE=$1
  SUM_OTHER_MONTH=$(cat $OUTPUT_FILE_OTHER_MONTH)
  SUM_OTHER_MONTH=$(expr $SUM_OTHER_MONTH + $PRICE)
  echo $SUM_OTHER_MONTH >$OUTPUT_FILE_OTHER_MONTH
}

write_today() {
  OUTPUT_FILE_TODAY=$(set_output_path "temp/ledger_$(date +"%Y%m%d").today")
  OUTPUT_FILE_YESTERDAY=$(set_output_path "temp/ledger_$(date -v-1d +"%Y%m%d").today")
  TYPE=$1
  SHOP=$2
  CONTENT=$3
  PRICE=$4
  if [[ ! -f $OUTPUT_FILE_TODAY ]]; then
    rm $OUTPUT_FILE_YESTERDAY
    echo 類別,店家,品項,價格 >$OUTPUT_FILE_TODAY
  fi
  echo "$TYPE","$SHOP","$CONTENT","$PRICE" >>$OUTPUT_FILE_TODAY
}

write_csv() {
  OUTPUT_FILE=$(set_output_path "data/ledger_$(date +"%Y%m").csv")
  OUTPUT_FILE_TEMP=$OUTPUT_FILE".temp"
  DATA_ROW=$1
  if [[ ! -f $OUTPUT_FILE ]]; then
    echo 日期,類別,店家,品項,價格 >$OUTPUT_FILE
  fi
  echo $DATA_ROW >>$OUTPUT_FILE
  mv $OUTPUT_FILE $OUTPUT_FILE_TEMP
  head -1 $OUTPUT_FILE_TEMP >$OUTPUT_FILE
  tail -n +2 $OUTPUT_FILE_TEMP | sort >>$OUTPUT_FILE
  rm $OUTPUT_FILE_TEMP
}

print_month() {
  COLOR_RED='\033[0;31m'
  COLOR_CYAN='\033[0;36m'
  COLOR_NORMAL='\033[0m'
  OUTPUT_TITLE=$(date +"%Y年%m月 花費明細")
  OUTPUT_FILE_MONTH=$(set_output_path "data/ledger_$(date +"%Y%m").csv")
  if [[ ! -f $OUTPUT_FILE_MONTH ]]; then
    echo ""
    echo "${COLOR_RED}本月尚未有記帳${COLOR_NORMAL}"
    echo ""
    exit 0
  fi
  OUTPUT_FILE_FOOD_MONTH=$(set_output_path "temp/food_$(date +"%Y%m").month")
  OUTPUT_FILE_NECESSARY_MONTH=$(set_output_path "temp/necessary_$(date +"%Y%m").month")
  OUTPUT_FILE_OTHER_MONTH=$(set_output_path "temp/other_$(date +"%Y%m").month")
  FOOD_MONTH=$(cat $OUTPUT_FILE_FOOD_MONTH)
  NECESSARY_MONTH=$(cat $OUTPUT_FILE_NECESSARY_MONTH)
  OTHER_MONTH=$(cat $OUTPUT_FILE_OTHER_MONTH)
  SUM_MONTH=$(expr $FOOD_MONTH + $NECESSARY_MONTH + $OTHER_MONTH)
  echo ""
  echo "${COLOR_CYAN}$OUTPUT_TITLE${COLOR_NORMAL}"
  echo ""
  cat $OUTPUT_FILE_MONTH | column -t -s ,
  echo ""
  echo "食物花費： $FOOD_MONTH, 必須花費： $NECESSARY_MONTH, 其他花費： $OTHER_MONTH"
  echo "本月總花費： $SUM_MONTH"
  echo ""
}

print_today() {
  COLOR_RED='\033[0;31m'
  COLOR_CYAN='\033[0;36m'
  COLOR_NORMAL='\033[0m'
  OUTPUT_TITLE=$(date +"%Y年%m月%d日 花費明細")
  OUTPUT_FILE_TODAY=$(set_output_path "temp/ledger_$(date +"%Y%m%d").today")
  if [[ ! -f $OUTPUT_FILE_TODAY ]]; then
    echo ""
    echo "${COLOR_RED}今日尚未有記帳${COLOR_NORMAL}"
    echo ""
    exit 0
  fi
  OUTPUT_FILE_CODA_TODAY=$(set_output_path "temp/coda.today")
  OUTPUT_FILE_SUM_TODAY=$(set_output_path "temp/sum.today")
  CODA_TODAY=$(cat $OUTPUT_FILE_CODA_TODAY)
  SUM_TODAY=$(cat $OUTPUT_FILE_SUM_TODAY)
  echo ""
  echo "${COLOR_CYAN}$OUTPUT_TITLE${COLOR_NORMAL}"
  echo ""
  cat $OUTPUT_FILE_TODAY | column -t -s ,
  echo ""
  echo "本日剩餘食費： $CODA_TODAY, 本日總和： $SUM_TODAY"
  echo ""
}

print_help() {
  echo ""
  echo "Usage: 一般記帳  al (-f --food 類別:食物)  店家 品項 價格"
  echo "                    (-n --necessary 類別:必須)"
  echo "                    (-o --other 類別:其他)"
  echo "       本日狀態  al -t --today"
  echo "       本月狀態  al -m --month"
  echo "       取得幫助  al -h --help"
  echo ""
  echo "Example: al -f 食物店名 食物品項 100"
  echo "         al -n 購買店名 購買品項 450"
  echo "         al -o 飲料店名 飲料品項 50"
  echo ""
  echo "note: 如資料中有空格記得用雙引號包起來，另外注意不能有逗號"
  echo ""
}

print_error() {
  COLOR_RED='\033[0;31m'
  COLOR_NORMAL='\033[0m'
  ERROR_MSG=$1
  echo ""
  echo "${COLOR_RED}錯誤：${ERROR_MSG}${COLOR_NORMAL}"
  echo ""
  exit 0
}

is_not_valid_integer() {
  if [[ $1 =~ ^-?[0-9]+$ ]]; then
    return 1
  else
    return 0
  fi
}

# functions
initialize_coda_today() {
  OUTPUT_FILE_CODA_TODAY=$(set_output_path "temp/coda.today")
  if [[ -f $OUTPUT_FILE_CODA_TODAY ]]; then
    CODA_YESTERDAY=$(cat $OUTPUT_FILE_CODA_TODAY)
    CODA_TODAY=$(expr $CODA_YESTERDAY + $CODA)
    echo $CODA_TODAY >$OUTPUT_FILE_CODA_TODAY
  else
    echo $CODA >$OUTPUT_FILE_CODA_TODAY
  fi
}

initialize_sum_today() {
  OUTPUT_FILE_SUM_TODAY=$(set_output_path "temp/sum.today")
  echo 0 >$OUTPUT_FILE_SUM_TODAY
}

initialize_food_month() {
  OUTPUT_FILE_FOOD_MONTH=$(set_output_path "temp/food_$(date +"%Y%m").month")
  echo 0 >$OUTPUT_FILE_FOOD_MONTH
  OUTPUT_FILE_CODA_TODAY=$(set_output_path "temp/coda.today")
  CODA_TODAY=$(cat $OUTPUT_FILE_CODA_TODAY)
  if [[ $CODA_TODAY != $CODA ]]; then
    echo $CODA >$OUTPUT_FILE_CODA_TODAY
  fi
}

initialize_necessary_month() {
  OUTPUT_FILE_NECESSARY_MONTH=$(set_output_path "temp/necessary_$(date +"%Y%m").month")
  echo 0 >$OUTPUT_FILE_NECESSARY_MONTH
}

initialize_other_month() {
  OUTPUT_FILE_OTHER_MONTH=$(set_output_path "temp/other_$(date +"%Y%m").month")
  echo 0 >$OUTPUT_FILE_OTHER_MONTH
}

update_coda() {
  OUTPUT_FILE_CODA_TODAY=$(set_output_path "temp/coda.today")
  PRICE=$1
  if [[ ! -f $OUTPUT_FILE_CODA_TODAY ]]; then
    echo $CODA >$OUTPUT_FILE_CODA_TODAY
  fi
  CODA_TODAY=$(cat $OUTPUT_FILE_CODA_TODAY)
  CODA_TODAY=$(expr $CODA_TODAY - $PRICE)
  echo $CODA_TODAY >$OUTPUT_FILE_CODA_TODAY
}

update_sum() {
  OUTPUT_FILE_SUM_TODAY=$(set_output_path "temp/sum.today")
  PRICE=$1
  if [[ ! -f $OUTPUT_FILE_SUM_TODAY ]]; then
    echo 0 >$OUTPUT_FILE_SUM_TODAY
  fi
  SUM_TODAY=$(cat $OUTPUT_FILE_SUM_TODAY)
  SUM_TODAY=$(expr $SUM_TODAY + $PRICE)
  echo $SUM_TODAY >$OUTPUT_FILE_SUM_TODAY
}

update_today() {
  OUTPUT_FILE_TODAY=$(set_output_path "temp/ledger_$(date +"%Y%m%d").today")
  TYPE=$1
  SHOP=$2
  CONTENT=$3
  PRICE=$4
  if [[ ! -f $OUTPUT_FILE_TODAY ]]; then
    initialize_coda_today
    initialize_sum_today
  fi
  write_today $TYPE $SHOP $CONTENT $PRICE
  if [ "$TYPE" == "食物" ]; then
    update_coda $PRICE
  fi
  update_sum $PRICE
  print_today
}

update_month() {
  OUTPUT_FILE_FOOD_MONTH=$(set_output_path "temp/food_$(date +"%Y%m").month")
  OUTPUT_FILE_NECESSARY_MONTH=$(set_output_path "temp/necessary_$(date +"%Y%m").month")
  OUTPUT_FILE_OTHER_MONTH=$(set_output_path "temp/other_$(date +"%Y%m").month")
  TYPE=$1
  PRICE=$2
  if [[ ! -f $OUTPUT_FILE_FOOD_MONTH ]]; then
    initialize_food_month
  fi
  if [[ ! -f $OUTPUT_FILE_NECESSARY_MONTH ]]; then
    initialize_necessary_month
  fi
  if [[ ! -f $OUTPUT_FILE_OTHER_MONTH ]]; then
    initialize_other_month
  fi
  case $TYPE in
    -f | --food)
      write_food_month $PRICE
      ;;
    -n | --necessary)
      write_necessary_month $PRICE
      ;;
    -o | --other)
      write_other_month $PRICE
      ;;
  esac
}

ledger() {
  TYPE=$1
  SHOP=$2
  CONTENT=$3
  PRICE=$4
  if is_not_valid_integer "$PRICE"; then
    print_error "價格不是合法整數"
  else
    DATE_TODAY=$(date +"%Y%m%d")
    update_month $TYPE $PRICE
    case $TYPE in
      -f | --food)
        write_csv "$DATE_TODAY",食物,"$SHOP","$CONTENT","$PRICE"
        update_today 食物 $SHOP $CONTENT $PRICE
        ;;
      -n | --necessary)
        write_csv "$DATE_TODAY",必須,"$SHOP","$CONTENT","$PRICE"
        update_today 必須 $SHOP $CONTENT $PRICE
        ;;
      -o | --other)
        write_csv "$DATE_TODAY",其他,"$SHOP","$CONTENT","$PRICE"
        update_today 其他 $SHOP $CONTENT $PRICE
        ;;
    esac
  fi
}

if [[ $# -eq 0 ]]; then
  print_help
else
  ARG=$1
  SHOP=$2
  CONTENT=$3
  PRICE=$4
  case $ARG in
    -f | --food | -n | --necessary | -o | --other)
      if [[ $# -eq 4 ]]; then
        ledger $ARG $SHOP $CONTENT $PRICE
      else
        print_error "參數數量錯誤，請使用 al -h 觀看範例"
      fi
      ;;
    -t | --today)
      print_today
      ;;
    -m | --month)
      print_month
      ;;
    -h | --help)
      print_help
      ;;
    *)
      print_help
      ;;
  esac
fi
