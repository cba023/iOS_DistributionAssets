#!/bin/bash

export LANG=en_US.UTF-8

# 帮助
if [[ $1 = "--help" ]] || [[ $1 = "-h" ]]; then
    echo "\033[32miOS构建脚本\033[0m\n"
    echo "选项列表:\n"
    echo "-a Address of Download，不传入自动设置为localhost(不需要传入http或https协议)"
    echo "-b Build Configuration，不传入自动构建Release"
    echo "-s 构建的Scheme，不传入则自动根据项目名称构建生产环境"
    echo "-u 构建的更新内容，不同项以';'隔开, 不传入则自动读取Git最后的提交日志"
    echo "-p 当前用户密码，用于获取系统调用权限，默认'123456'"
    exit 0
fi

cd ..
# 获取工程名，根据*.xcworkspace格式判断
for file in $(ls ./); do
    if [ "${file##*.}" = "xcworkspace" ]; then
        __THIS_PROJECT_NAME=${file%.*}
        break
    fi
done
# 获取git提交的message
__IMPORT_UPDATE_CONTENT=$(git log --format=%B -n 1 HEAD)
cd ./AutoSh
__APP_NAME="APP1"
__SCHEME_NAME="${__THIS_PROJECT_NAME}"
__BUILD_CONF="Release"
__PASSWORD="123456"
__HOST="192.168.0.103"

while getopts ":a:b:s:u:p:" opt; do
    case $opt in
    a)
        __HOST=$OPTARG
        echo "__HOST: $__HOST"
        ;;
    b)
        __BUILD_CONF=$OPTARG
        echo "__BUILD_CONF: $__BUILD_CONF"
        ;;
    s)
        __SCHEME_NAME=$OPTARG
        echo "__SCHEME_NAME: $__SCHEME_NAME"
        ;;
    u)
        __IMPORT_UPDATE_CONTENT=$OPTARG
        echo "__IMPORT_UPDATE_CONTENT: $__IMPORT_UPDATE_CONTENT"
        ;;
    p)
        __PASSWORD=$OPTARG
        echo "__PASSWORD: $__PASSWORD"
        ;;
    \?)
        echo "Invalid option: -$OPTARG"
        ;;
    esac
done

# 创建sudo别名
alias rodo='echo "${__PASSWORD}" | sudo -S'
# # 从keychain处获取用户权限
security -v unlock-keychain -p $__PASSWORD "/Users/`whoami`/Library/Keychains/login.keychain"
cd ..
__PROJECT_DIR=$(pwd)
echo "__PROJECT_DIR: ${__PROJECT_DIR}"

__UPDATE_CONTENT=$(echo $__IMPORT_UPDATE_CONTENT | sed -n 's/；/;/g; s/ ;/;/g;s/; /;/g;'p) # 分号格式化

# ↓将更新信息构造成数组，单个元素中允许存在空格
__UPDATES=()
i=1
while((1==1))
do
  splitchar=`echo $__UPDATE_CONTENT|cut -d ";" -f$i`
  if [ "$splitchar" != "" ]
  then
    __UPDATES[i]="${splitchar}"
    ((i++))
  else
    break
  fi
done

echo "\n\033[32m更新内容:\033[0m"

for item in "${__UPDATES[@]}"; do
    echo "\033[32m* ${item}\033[0m"
done
echo "\n"
# ↑ 数组完成转换

echo "__THIS_PROJECT_NAME:${__THIS_PROJECT_NAME}"

__FORMATTED_TIME_TO_FILE=$(date +%Y%m%d_%H%M%S)
__FORMATTED_YEAR_MONTH_DAY=$(date +%Y-%m-%d)
__FORMATTED_YEAR_HHMMSS=$(date +%H:%M:%S)
__FORMATTED_TIME_TO_DIS=$(date +'%Y-%m-%d %H:%M:%S')
__WORK_SPACE="${__THIS_PROJECT_NAME}.xcworkspace"
__USER_NAME="$(whoami)"
__HOST_NAME=$(hostname)
__USER_DIR="/Users/$(whoami)"
__EXPORT_DIR="${__USER_DIR}/iOS_Distribution"
__EXPORT_BUILDING_DIR="${__EXPORT_DIR}/Output"
__EXPORT_ARCHIVE_PATH="${__EXPORT_BUILDING_DIR}/${__THIS_PROJECT_NAME}.xcarchive"
__EXPORT_IPA_PATH="${__EXPORT_BUILDING_DIR}/${__THIS_PROJECT_NAME}.ipa"
__EXPORT_ADHOC_OPTION_PLIST_PATH="./AutoSh/ExportOptions_adhoc.plist"
__BUNDLE_VERSION=$(
    cd .. &
    xcodebuild -showBuildSettings -scheme $__SCHEME_NAME | grep MARKETING_VERSION | tr -d 'MARKETING_VERSION ='
)

echo "__BUNDLE_VERSION: ${__BUNDLE_VERSION}"
echo "__APP_NAME: ${__APP_NAME}"
echo "__SCHEME_NAME: ${__SCHEME_NAME}"
echo "__BUILD_CONF: ${__BUILD_CONF}"
echo "__FORMATTED_TIME_TO_FILE: ${__FORMATTED_TIME_TO_FILE}"
echo "__WORK_SPACE: ${__WORK_SPACE}"
echo "__USER_NAME: ${__USER_NAME}"
echo "__USER_DIR: ${__USER_DIR}"
echo "__EXPORT_ARCHIVE_PATH: ${__EXPORT_ARCHIVE_PATH}"
echo "__EXPORT_IPA_PATH: ${__EXPORT_IPA_PATH}"
echo "__EXPORT_ADHOC_OPTION_PLIST_PATH: ${__EXPORT_ADHOC_OPTION_PLIST_PATH}"

echo "\n开始安装CocoaPods依赖库"
pod cache clean --all
pod install

# clean
echo "\n清理工作空间"
xcodebuild clean \
    -workspace ${__WORK_SPACE} \
    -scheme ${__SCHEME_NAME} \
    -configuration ${__BUILD_CONF}

# archive
echo "\n开始归档工程"
xcodebuild archive \
    -workspace ${__WORK_SPACE} \
    -scheme ${__SCHEME_NAME} \
    -configuration ${__BUILD_CONF} \
    -archivePath ${__EXPORT_ARCHIVE_PATH}

# export
echo "\n开始导出项目(Adhoc)"
xcodebuild \
    -exportArchive \
    -archivePath ${__EXPORT_ARCHIVE_PATH} \
    -exportPath ${__EXPORT_BUILDING_DIR} \
    -exportOptionsPlist ${__EXPORT_ADHOC_OPTION_PLIST_PATH} \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration

# 检查ipa文件是否已经成功创建
echo "__EXPORT_IPA_PATH: ${__EXPORT_IPA_PATH}"
if [[ -f "${__EXPORT_IPA_PATH}" ]]; then
    echo "已导出 ${__EXPORT_IPA_PATH}"

else
    echo "未导出 ${__EXPORT_IPA_PATH}"
    exit
fi

# 配置服务信息
__SERVER_DIR="/Users/`whoami`/DAPP"
if [ ! -d "$__SERVER_DIR" ]; then
    echo "自动创建服务目录"
    rodo mkdir $__SERVER_DIR
fi

__CURRNET_BUILD_APP_NAME="${__SCHEME_NAME}_${__BUNDLE_VERSION}_${__FORMATTED_TIME_TO_FILE}"
__CURRNET_BUILD_FILE_PATH="${__SERVER_DIR}/Apps"
__APP_FILE_NAME="${__CURRNET_BUILD_FILE_PATH}/${__CURRNET_BUILD_APP_NAME}"
__CURRNET_BUILD_IPA_PATH="${__APP_FILE_NAME}.ipa"
__CURRNET_BUILD_IPA_PLIST_PATH="${__APP_FILE_NAME}.plist"
__CURRNET_BUILD_DSYM_PATH="${__APP_FILE_NAME}.ipa.dSYM"

__CURRNET_BUILD_RECORDS_PATH="${__SERVER_DIR}/Records"

echo "__CURRNET_BUILD_FILE_PATH: ${__CURRNET_BUILD_FILE_PATH}"
echo "__CURRNET_BUILD_IPA_PATH: ${__CURRNET_BUILD_IPA_PATH}"

if [ ! -d "$__CURRNET_BUILD_FILE_PATH" ]; then
    rodo mkdir $__CURRNET_BUILD_FILE_PATH
fi
rodo cp ${__EXPORT_IPA_PATH} ${__CURRNET_BUILD_IPA_PATH}

if [ ! -d "$__CURRNET_BUILD_RECORDS_PATH" ]; then
    rodo mkdir $__CURRNET_BUILD_RECORDS_PATH
fi

# 提取符号表并压缩
echo "提取符号表并压缩"
__DSYM_PATH="${__EXPORT_ARCHIVE_PATH}/dSYMs/${__THIS_PROJECT_NAME}.app.dSYM"
rodo cp -R ${__DSYM_PATH} ${__CURRNET_BUILD_DSYM_PATH}
__LAST_DIR=$(pwd)
cd $__CURRNET_BUILD_FILE_PATH
rodo zip -r "${__CURRNET_BUILD_DSYM_PATH}.zip" "./${__CURRNET_BUILD_APP_NAME}.ipa.dSYM"
rodo rm -rf "${__CURRNET_BUILD_DSYM_PATH}"
cd $__LAST_DIR

# 下载信息配置
__CURRNET_BUILD_DOWN_PATH="${__HOST}/Apps"
__IPA_DOWNLOAD_URL="http://${__CURRNET_BUILD_DOWN_PATH}/${__CURRNET_BUILD_APP_NAME}.ipa"
__IPA_DOWNLOAD_URL_S="https://${__CURRNET_BUILD_DOWN_PATH}/${__CURRNET_BUILD_APP_NAME}.ipa"
__IPA_INSTALL_URL="https://${__CURRNET_BUILD_DOWN_PATH}/${__CURRNET_BUILD_APP_NAME}.plist"
__DSYM_DOWNLOAD_URL="${__IPA_DOWNLOAD_URL}.dSYM.zip"
__HISTORY_VERSIONS_JSON_URL="http://${__HOST}/Records/History_versions.json"

# 检查PlistBuddy是否存在
if [[ ! -x /usr/libexec/PlistBuddy ]]; then
    echo 'Error: PlistBuddy is not installed'
    exit
fi

iconSmallFileName="image_57x57.png"
iconBigFileName="image_512x512.png"
iconSmallUrl="https://${__HOST}/images/${iconSmallFileName}"
iconBigurl="https://${__HOST}/images/${iconBigFileName}"

__BUNDLE_BUILD_VERSION=$(xcodebuild -showBuildSettings -scheme $__SCHEME_NAME | grep CURRENT_PROJECT_VERSION | tr -d 'CURRENT_PROJECT_VERSION =')
# echo "__BUNDLE_BUILD_VERSION: ${__BUNDLE_BUILD_VERSION}"
__BUNDLE_IDENTIFIER=$(xcodebuild -showBuildSettings -scheme $__SCHEME_NAME | grep PRODUCT_BUNDLE_IDENTIFIER | tr -d 'PRODUCT_BUNDLE_IDENTIFIER =')
__GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
__GIT_COMMIT_ID=$(git log --pretty=format:"%h" | head -1 | awk '{print $1}')
__INSTALL_LINK="itms-services://?action=download-manifest&url=${__IPA_INSTALL_URL}"

rodo cp "${__EXPORT_DIR}/Others/base.plist" ${__CURRNET_BUILD_IPA_PLIST_PATH}
rodo /usr/libexec/PlistBuddy -c "Add :items:0:assets:0:url string ${__IPA_DOWNLOAD_URL_S}" ${__CURRNET_BUILD_IPA_PLIST_PATH}
rodo /usr/libexec/PlistBuddy -c "Add :items:0:assets:1:url string ${iconSmallUrl}" ${__CURRNET_BUILD_IPA_PLIST_PATH}
rodo /usr/libexec/PlistBuddy -c "Add :items:0:assets:2:url string ${iconBigurl}" ${__CURRNET_BUILD_IPA_PLIST_PATH}
rodo /usr/libexec/PlistBuddy -c "Add :items:0:metadata:bundle-identifier string ${__BUNDLE_IDENTIFIER}" ${__CURRNET_BUILD_IPA_PLIST_PATH}
rodo /usr/libexec/PlistBuddy -c "Add :items:0:metadata:bundle-version string ${__BUNDLE_VERSION}" ${__CURRNET_BUILD_IPA_PLIST_PATH}
rodo /usr/libexec/PlistBuddy -c "Add :items:0:metadata:title string ${__APP_NAME}" ${__CURRNET_BUILD_IPA_PLIST_PATH}

__VERSION_PLIST_PATH="${__CURRNET_BUILD_RECORDS_PATH}/History_versions.plist"
__VERSION_LIST_JSON_PATH="${__CURRNET_BUILD_RECORDS_PATH}/History_versions.json"

__RECORDS_PLIST_PATH="${__CURRNET_BUILD_RECORDS_PATH}/Build_records_${__BUNDLE_VERSION}.plist"
__RECORDS_LIST_JSON_NAME="Build_records_${__BUNDLE_VERSION}.json"
__RECORDS_LIST_JSON_PATH="${__CURRNET_BUILD_RECORDS_PATH}/${__RECORDS_LIST_JSON_NAME}"
echo "导出构建记录到路径: ${__RECORDS_PLIST_PATH}"
__SSL_PATH="http://${__HOST}/ssl/self-signed.crt"

################################## History_versions.plist ####################################

if [ ! -f "$__VERSION_PLIST_PATH" ]; then
    rodo cp "${__EXPORT_DIR}/Others/blank.plist" ${__VERSION_PLIST_PATH}
    rodo /usr/libexec/PlistBuddy -c "Add :create_time string ${__FORMATTED_TIME_TO_DIS}" $__VERSION_PLIST_PATH
    rodo /usr/libexec/PlistBuddy -c "Add :app_name string ${__APP_NAME}" $__VERSION_PLIST_PATH
    rodo /usr/libexec/PlistBuddy -c "Add :update_time string ${__FORMATTED_TIME_TO_DIS}" $__VERSION_PLIST_PATH
    rodo /usr/libexec/PlistBuddy -c "Add :version_list dict" $__VERSION_PLIST_PATH
else
    rodo /usr/libexec/PlistBuddy -c "Set :app_name ${__APP_NAME}" $__VERSION_PLIST_PATH
    rodo /usr/libexec/PlistBuddy -c "Set :update_time ${__FORMATTED_TIME_TO_DIS}" $__VERSION_PLIST_PATH
    rodo /usr/libexec/PlistBuddy -c "Delete :version_list:${__BUNDLE_VERSION}" $__VERSION_PLIST_PATH
fi

rodo /usr/libexec/PlistBuddy -c "Add :version_list:${__BUNDLE_VERSION}:json_path string ./${__RECORDS_LIST_JSON_NAME}" $__VERSION_PLIST_PATH
rodo plutil -convert json ${__VERSION_PLIST_PATH} -o ${__VERSION_LIST_JSON_PATH}

################################## Build_records_*.plist ####################################

if [ ! -f "$__RECORDS_PLIST_PATH" ]; then
    rodo cp "${__EXPORT_DIR}/Others/blank.plist" ${__RECORDS_PLIST_PATH}
    rodo /usr/libexec/PlistBuddy -c "Add :create_time string ${__FORMATTED_TIME_TO_DIS}" $__RECORDS_PLIST_PATH
    rodo /usr/libexec/PlistBuddy -c "Add :app_name string ${__APP_NAME}" $__RECORDS_PLIST_PATH
    rodo /usr/libexec/PlistBuddy -c "Add :project_name string ${__THIS_PROJECT_NAME}" $__RECORDS_PLIST_PATH
    rodo /usr/libexec/PlistBuddy -c "Add :ssl string ${__SSL_PATH}" $__RECORDS_PLIST_PATH
    rodo /usr/libexec/PlistBuddy -c "Add :update_time string ${__FORMATTED_TIME_TO_DIS}" $__RECORDS_PLIST_PATH
    rodo /usr/libexec/PlistBuddy -c "Add :build_list array" $__RECORDS_PLIST_PATH
else
    rodo /usr/libexec/PlistBuddy -c "Set :app_name ${__APP_NAME}" $__RECORDS_PLIST_PATH
    rodo /usr/libexec/PlistBuddy -c "Set :project_name ${__THIS_PROJECT_NAME}" $__RECORDS_PLIST_PATH
    rodo /usr/libexec/PlistBuddy -c "Set :ssl ${__SSL_PATH}" $__RECORDS_PLIST_PATH
    rodo /usr/libexec/PlistBuddy -c "Set :update_time ${__FORMATTED_TIME_TO_DIS}" $__RECORDS_PLIST_PATH
fi

__BUILD_LIST_CONTENT=$(rodo /usr/libexec/PlistBuddy -c "Print :build_list" $__RECORDS_PLIST_PATH)
__BUILD_LIST_PLIST_ARR=$(rodo /usr/libexec/PlistBuddy -c "Print :build_list" ${__RECORDS_PLIST_PATH})

dict_keyword=""" Dict {"""
# 获取现存build_list的长度，在此基础上填充数据
__BUILD_LIST_LENGTH=$(echo ${__BUILD_LIST_PLIST_ARR} | grep -wo "${dict_keyword}" | wc -l)

__FORMATTED_CURRENT_DATE_TIME=$(date +'%Y-%m-%d %H:%M:%S')
__IPA_SIZE=`du -sh "${__CURRNET_BUILD_IPA_PATH}" | awk '{print $1}'`
# rodo rm -rf ${__RECORDS_LIST_TEMP_PATH}
# echo ${__BUILD_LIST_LENGTH}
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):version string ${__BUNDLE_VERSION}" $__RECORDS_PLIST_PATH
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):pack_name string ${__CURRNET_BUILD_APP_NAME}.ipa" $__RECORDS_PLIST_PATH
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):build_conf string ${__BUILD_CONF}" $__RECORDS_PLIST_PATH
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):build_time string ${__FORMATTED_TIME_TO_DIS}" $__RECORDS_PLIST_PATH
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):bundle_id string ${__BUNDLE_IDENTIFIER}" $__RECORDS_PLIST_PATH
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):build_version string ${__BUNDLE_BUILD_VERSION}" $__RECORDS_PLIST_PATH
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):git_commit_id string ${__GIT_COMMIT_ID}" $__RECORDS_PLIST_PATH
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):git_branch string ${__GIT_BRANCH}" $__RECORDS_PLIST_PATH
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):build_user string ${__USER_NAME}" $__RECORDS_PLIST_PATH
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):build_host_name string ${__HOST_NAME}" $__RECORDS_PLIST_PATH
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):install_link string ${__INSTALL_LINK}" $__RECORDS_PLIST_PATH
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):download_link string ${__IPA_DOWNLOAD_URL}" $__RECORDS_PLIST_PATH
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):dsym_download_link string ${__DSYM_DOWNLOAD_URL}" $__RECORDS_PLIST_PATH
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):ipa_size string ${__IPA_SIZE}" $__RECORDS_PLIST_PATH
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):scheme_name string ${__SCHEME_NAME}" $__RECORDS_PLIST_PATH

# 更新内容
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):updates array" $__RECORDS_PLIST_PATH
for i in ${!__UPDATES[@]}; do
    rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):updates:$(($i)) string ${__UPDATES[$i]}" $__RECORDS_PLIST_PATH
done
rodo plutil -convert json ${__RECORDS_PLIST_PATH} -o ${__RECORDS_LIST_JSON_PATH}

echo "构建开始时间: ${__FORMATTED_TIME_TO_DIS}"
echo "构建结束时间: ${__FORMATTED_CURRENT_DATE_TIME}"
start_date=$(date -j -f '%Y-%m-%d %H:%M:%S' "$__FORMATTED_TIME_TO_DIS" '+%s')
end_date=$(date -j -f '%Y-%m-%d %H:%M:%S' "$__FORMATTED_CURRENT_DATE_TIME" '+%s')
duration=$(expr $end_date - $start_date) #计算2个时间的差
if [ $duration -lt 60 ]; then
    duration_time="${duration}秒"
else
    if [ $((duration / 60 / 60)) -lt 1 ]; then
        duration_time="$((duration / 60))分$((duration % 60))秒"
    else
        duration_time="$((duration / 60 / 60))时$((duration / 60 % 60))分$((duration % 60))秒"
    fi
fi
rodo /usr/libexec/PlistBuddy -c "Add :build_list:$(($__BUILD_LIST_LENGTH)):build_finished_time string ${__FORMATTED_CURRENT_DATE_TIME}" $__RECORDS_PLIST_PATH
echo "构建耗时: ${duration_time}"
echo "\033[32m任务完成\033[0m"

