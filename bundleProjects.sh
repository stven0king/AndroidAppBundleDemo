#!/usr/bin/env bash

BASE_PROJECT_NAME="app"
APKS_TEMP_DIR="Apks";
BUNDLE_TEMP_DIR="basebundle"
BUNDLE_TOOL_FILE_NAME="bundletool-all-1.2.0.jar"
PHONE_SPEC_FILE_NAME="phone.json"
BUNDLE_APKS_TEMP_DIR="apks"


function getApk() {
#    local name=""
##
##    gradle $name:"assembleDebug"
#    name=cat pwd
#    echo ${name}

    devicespec
}

function devicespec() {
    
    if [ -d ${BUNDLE_TEMP_DIR} ]; then
      echo "已存在"
    else
      echo "不存在创建"
      mkdir ${BUNDLE_TEMP_DIR}
    fi
  
    #根目录
    project_path=$(cd `dirname $0`; pwd)

    #拷贝aab到指定目录
    cd "${BASE_PROJECT_NAME}/build/outputs/bundle/debug"
    ls
    cmd="cp -r ${BASE_PROJECT_NAME}.aab ../../../../../${BUNDLE_TEMP_DIR}"
    $cmd

    #获取手机配置信息
    cd $project_path/$BUNDLE_TEMP_DIR
    if [ -f ${PHONE_SPEC_FILE_NAME} ]; then
        echo "存在旧配置删除"
        rm -rf ${PHONE_SPEC_FILE_NAME}
    fi
    ## 创建新的配置
    java -jar ../bundletool/${BUNDLE_TOOL_FILE_NAME} get-device-spec --output=${PHONE_SPEC_FILE_NAME}


    #创建apks目录
    if [ -d ${BUNDLE_APKS_TEMP_DIR} ]; then
      echo "已存在"
      cd ${BUNDLE_APKS_TEMP_DIR}
      rm -rf ${BASE_PROJECT_NAME}.apks
      cd ..
    else
      echo "不存在创建"
      mkdir ${BUNDLE_APKS_TEMP_DIR}
    fi
    #将bundle 转换成apks
    java -jar ../bundletool/${BUNDLE_TOOL_FILE_NAME} build-apks --bundle=./${BASE_PROJECT_NAME}.aab --output=${BUNDLE_APKS_TEMP_DIR}/${BASE_PROJECT_NAME}.apks
    #产出特定apk
    java -jar ../bundletool/${BUNDLE_TOOL_FILE_NAME} extract-apks --apks=./apks/${BASE_PROJECT_NAME}.apks --output-dir=$project_path/${BUNDLE_TEMP_DIR}/apks/ --device-spec=./${PHONE_SPEC_FILE_NAME}

}



#迁移安装包到新的apks目录
function copyApks() {
#    parseSettingGradleProjects
#    for projectName in ${projectList[@]} #遍历parseSettingGradleProjects结果
#    do
#    done

#    cd Apks
#    ls
#    for dir in ${dirarr[*]}
#    do
#	    filearr=$(ls $dir);
#	    for file in ${filearr[*]}
#	    do
#        echo "1111"
#	    done
#    done

#    rm -ir ${APKS_TEMP_DIR}
#    ls
#    mkdir ${APKS_TEMP_DIR}
#    ls

    #清空目录下删一次缓存的apk
    cd ${APKS_TEMP_DIR}
    path=$1
    files=$(ls $path)
    for filename in $files
    do
      echo $filename
      rm -rf ${filename}
    done
    cd ..

    project_path=$(cd `dirname $0`; pwd)
    #遍历所有的工程和子工程
    parseSettingGradleProjects
    for projectName in ${projectList[@]} #遍历parseSettingGradleProjects结果
    do
        echo $projectName
        dir=$projectName"/build/outputs/apk/debug"
        cd ${dir}
        local fileName="$projectName-debug.apk"
        if [ -f ${fileName} ]; then
            allfiles="${allfiles} ${fileName}"
            #拷贝文件到指定目录（Apks）
            cp -r ${fileName} "../../../../../${APKS_TEMP_DIR}"
        fi
        cd ${project_path}
    done
}


function installApks() {
    allfiles="";
    cd ${APKS_TEMP_DIR}
    path=$1
    files=$(ls $path)
    for filename in $files
    do
      allfiles="${allfiles} ${filename}"
    done
    #安装
    adb install-multiple [-r] ${allfiles}
}



#单独安装一个feature
function featureRun() {
    featureName=$1
    index=0
    #打最新的feature包
#    gradle :${featureName}:assembleDebug
    #检查包目录
#    if [ -d ${APKS_TEMP_DIR} ]; then
#       echo "目录存在"
#    else
#      echo "目录不存在 创建目录"
#      mkdir ${APKS_TEMP_DIR}
#    fi

    #查询完整性
    parseSettingGradleProjects
    local dir=""
    local cmd=""
    project_path=$(cd `dirname $0`; pwd)

    for projectName in ${projectList[@]} #遍历parseSettingGradleProjects结果
    do
        echo $projectName
        dir=$projectName"/build/outputs/apk/debug"
        cd ${dir}
        local fileName="$projectName-debug.apk"
        echo $fileName
        if [ -f ${fileName} ]; then
          echo "exist"
          echo "${featureName}==${projectName}"
          if [ ${featureName} = ${projectName} ]; then
              echo "重新构建"
              cd ${project_path}
              cmd=gradle" ${projectName}:assembleDebug"
              echo $cmd
              $cmd
              cd ${dir}
          fi
        elif [ $projectName = "app" ]; then
          echo "unexit app"
          cd ${project_path}
          cmd=gradle" ${projectName}:assembleDebug"
          echo $cmd
          $cmd
          cd ${dir}

        else
          echo "unexit feature"
          cmd=gradle" ${projectName}:assembleDebug"
          echo $cmd
          $cmd

        fi

        let index+=1
        cd ..
        cd ..
        cd ..
        cd ..
        cd ..
    done

    copyApks
    installApks

}




# 打包feature.apk
function featureBuild() {
    featureName=$1
    local buildType=""
    if [ $2 = "debug" ]; then
        buildType="assembleDebug"
    else
        buildType="assembleRelease"
    fi
    gradle :${featureName}:"${buildType}"
}

# 打包 base.aab
function bundleBuild() {
    local bundleType=""
    if [ "$1"=="debug" ]; then
        bundleType="bundleDebug"
    else
       bundleType="bundleRelease"
    fi

    gradle :$BASE_PROJECT_NAME":${bundleType}"
}


# 根据setting.gradle获取所有子Project名的功能
function parseSettingGradleProjects() {
    index=0
    projectList=()

    # 此处while无法用管道｜命令，否则projectList无法正确写入
    while read line || [[ -n ${line} ]];
    do
        if [[ ${line} == include* ]] || [[ ${line} == \':* ]]; then
            echo "Include line：$line"
            lineTemp=${line#*\include} #删除include及其左边的内容
            lineTemp=${lineTemp%\//*} #删除//及其右边的内容，兼容,号前可能有空格的问题
#            echo "formate》${lineTemp}"
            array=(${lineTemp//,/ })

            for var in ${array[@]}
            do
               temp=${var#*\:} #删除:及其左边的内容
               projectName=${temp%\'*} #删除‘及其右边的内容
               if [ -n "${projectName}" ];then #如果结果不为空
                    projectList[${index}]="${projectName}"
                    let index+=1
                    echo "ProjectName ${index}：${projectName}"
               fi
            done
        elif [[ ${line} == Dep.include* ]]; then
            echo "Dep line：$line"
            lineTemp=${line#*\,} #删除,及其左边的内容
            lineTemp=${lineTemp%\//*} #删除//及其右边的内容，兼容,号前可能有空格的问题
            lineTemp=${lineTemp%\)*} #删除)及其右边的内容，兼容,号前可能有空格的问题
            lineTemp=${lineTemp#*\:} #删除:及其左边的内容
#            echo "formate》${lineTemp}"
            projectName=${lineTemp%\'*} #删除,及其右边的内容，兼容,号前可能有空格的问题
            modeName=${lineTemp#*\,} #删除,及其左边的内容
            if [[ " Mode.SOURCE" == "${modeName}" ]]; then
                echo "ProjectName：${projectName}使用源码"
                if [ -n "${projectName}" ];then #如果结果不为空
                    projectList[${index}]="${projectName}"
                    let index+=1
                    echo "ProjectName ${index}：${projectName}"
                fi
            else
                echo "ProjectName：${projectName}使用maven"
            fi

        else
            echo "ignore：${line}"
        fi
    done < settings.gradle

    echo "子Project数量: "${#projectList[@]} #打印数组长度
}


function help() {
    echo help
    echo ""
    echo featureRun [featurename]
    echo "  重新安装指定featurename  "
    echo ""
    echo featureBuild [featurename/buildtype]
    echo "   以指定类型（debug/release） 重新构建feature  "
    echo ""
    echo bundleBuild [buildtype]
    echo "  以指定类型（debug/release） 重新构建aab    "
    echo ""
    echo getApk
    echo "  根据SplitApk 生产基础安装包 apk  "
    echo ""
}


case $1 in


    "get")
        getApk
    ;;

    "featureRun")
        featureRun $2
    ;;

    "featureBuild")
        featureBuild $2 $3
    ;;

    "bundleBuild")
        bundleBuild $2
    ;;

    "help")
        help
    ;;
    *)
        help
        # 脚本顶部已经打印了当前Branch
        # 打印解析到的子Project
        parseSettingGradleProjects
    ;;
esac


