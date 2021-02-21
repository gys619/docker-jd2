#!/usr/bin/env bash

## Author: Evine Deng
## Source: https://github.com/EvineDeng/jd-base
## Modified： 2021-02-08
## Version： v3.6.3

## 文件路径、脚本网址、文件版本以及各种环境的判断
ShellDir=${JD_DIR:-$(cd $(dirname $0); pwd)}
[[ ${JD_DIR} ]] && ShellJd=jd || ShellJd=${ShellDir}/jd.sh
LogDir=${ShellDir}/log
[ ! -d ${LogDir} ] && mkdir -p ${LogDir}
ScriptsDir=${ShellDir}/scripts
ScriptsDir2=${ShellDir}/scripts2
ScriptsDir3=${ShellDir}/scripts3
ConfigDir=${ShellDir}/config
FileConf=${ConfigDir}/config.sh
FileDiy=${ConfigDir}/diy.sh
FileConfSample=${ShellDir}/sample/config.sh.sample
ListCron=${ConfigDir}/crontab.list
ListCronLxk=${ScriptsDir}/docker/crontab_list.sh
ListTask=${LogDir}/task.list
ListJs=${LogDir}/js.list
ListJsAdd=${LogDir}/js-add.list
ListJsDrop=${LogDir}/js-drop.list
ContentVersion=${ShellDir}/version
ContentNewTask=${ShellDir}/new_task
ContentDropTask=${ShellDir}/drop_task
SendCount=${ShellDir}/send_count
isTermux=${ANDROID_RUNTIME_ROOT}${ANDROID_ROOT}
ShellURL=https://github.com/kangwenhang/jd_docker2
ScriptsURL=git@gitee.com:lxk0301/jd_scripts.git

## 更新crontab，gitee服务器同一时间限制5个链接，因此每个人更新代码必须错开时间，每次执行git_pull随机生成。
## 每天次数随机，更新时间随机，更新秒数随机，至少6次，至多12次，大部分为8-10次，符合正态分布。
function Update_Cron {
  if [ -f ${ListCron} ]; then
    RanMin=$((${RANDOM} % 60))
    RanSleep=$((${RANDOM} % 56))
    RanHour=$((${RANDOM} % 60))
    #RanHourArray[0]=$((${RANDOM} % 3))
    #for ((i=1; i<14; i++)); do
    #  j=$(($i - 1))
    #  tmp=$((${RANDOM} % 3 + ${RanHourArray[j]} + 2))
    #  [[ ${tmp} -lt 24 ]] && RanHourArray[i]=${tmp} || break
    #done
    #RanHour=${RanHourArray[0]}
    #for ((i=1; i<${#RanHourArray[*]}; i++)); do
    #  RanHour="${RanHour},${RanHourArray[i]}"
    #done
    perl -i -pe "s|.+(bash git_pull.+)|${RanMin} ${RanHour} \* \* \* sleep ${RanSleep} && \1|" ${ListCron}
    crontab ${ListCron}
  fi
}

## 更新shell脚本
function Git_PullShell {
  echo -e "更新shell脚本，原地址：${ShellURL}\n"
  cd ${ShellDir}
  git fetch --all
  ExitStatusShell=$?
  git reset --hard origin/main
}

## 更新crontab
function Update_Cron {
  if [ -f ${ListCron} ]; then
    perl -i -pe "s|30 8-20/4(.+jd_nian\W*.*)|28 8-20/4,21\1|" ${ListCron} # 修改默认错误的cron
    crontab ${ListCron}
  fi
}

## 克隆scripts
function Git_CloneScripts {
  echo -e "克隆LXK9301脚本，原地址：${ScriptsURL}\n"
  git clone -b master ${ScriptsURL} ${ScriptsDir}
  ExitStatusScripts=$?
  echo
}

## 更新scripts
function Git_PullScripts {
  echo -e "更新LXK9301脚本，原地址：${ScriptsURL}\n"
  cd ${ScriptsDir}
  git fetch --all
  ExitStatusScripts=$?
  git reset --hard origin/master
  echo
}

## 克隆scripts2
function Git_CloneScripts2 {
  echo -e "克隆AutoSignMachine脚本，地址：${ShellURL}\n"
  git clone -b AutoSignMachine ${ShellURL} ${ScriptsDir2}
  ExitStatusScripts2=$?
  echo
}

## 更新scripts2
function Git_PullScripts2 {
  echo -e "更新AutoSignMachine脚本，地址：${ShellURL}\n"
  cd ${ScriptsDir2}
  git fetch --all
  ExitStatusScripts2=$?
  git reset --hard origin/AutoSignMachine
  echo
}

## 克隆scripts3
#function Git_CloneScripts3 {
#  echo -e "克隆BiliExp脚本，地址：${ShellURL}\n"
#  git clone -b BiliExp1.1.9 ${ShellURL} ${ScriptsDir3}
#  ExitStatusScripts3=$?
#  echo
#}

## 更新scripts3
#function Git_PullScripts3 {
#  echo -e "更新BiliExp脚本，地址：${ShellURL}\n"
#  cd ${ScriptsDir3}
#  git fetch --all
#  ExitStatusScripts3=$?
#  git reset --hard origin/BiliExp
#  echo
#}

## 用户数量UserSum
function Count_UserSum {
  i=1
  while [ $i -le 1000 ]; do
    Tmp=Cookie$i
    CookieTmp=${!Tmp}
    [[ ${CookieTmp} ]] && UserSum=$i || break
    let i++
  done
}

## 把config.sh中提供的所有账户的PIN附加在jd_joy_run.js中，让各账户相互进行宠汪汪赛跑助力
## 你的账号将按Cookie顺序被优先助力，助力完成再助力我的账号和lxk0301大佬的账号
function Change_JoyRunPins {
  j=${UserSum}
  PinALL=""
  while [[ $j -ge 1 ]]
  do
    Tmp=Cookie$j
    CookieTemp=${!Tmp}
    PinTemp=$(echo ${CookieTemp} | perl -pe "{s|.*pt_pin=(.+);|\1|; s|%|\\\x|g}")
    PinTempFormat=$(printf ${PinTemp})
    PinALL="${PinTempFormat},${PinALL}"
    let j--
  done
  PinEvine="Evine,做一颗潇洒的蛋蛋,Evine007,jd_7bb2be8dbd65c,jd_6fae2af082798,jd_664ecc3b78945,277548856_m,米大眼老鼠,"
  PinALL="${PinALL}${PinEvine}"
  perl -i -pe "{s|(let invite_pins = \[\")(.+\"\];?)|\1${PinALL}\2|; s|(let run_pins = \[\")(.+\"\];?)|\1${PinALL}\2|}" ${ScriptsDir}/jd_joy_run.js
}

## 修改lxk0301大佬js文件的函数汇总
function Change_ALL {
  if [ -f ${FileConf} ]; then
    . ${FileConf}
    if [ -n "${Cookie1}" ]; then
      Count_UserSum
      Change_JoyRunPins
    fi
  fi
}

## 检测文件：LXK0301/jd_scripts 仓库中的 docker/crontab_list.sh，和 shylocks/Loon 仓库中的 docker/crontab_list.sh
## 检测定时任务是否有变化，此函数会在Log文件夹下生成四个文件，分别为：
## task.list    crontab.list中的所有任务清单，仅保留脚本名
## js.list      上述检测文件中用来运行js脚本的清单（去掉后缀.js，非运行脚本的不会包括在内）
## js-add.list  如果上述检测文件增加了定时任务，这个文件内容将不为空
## js-drop.list 如果上述检测文件删除了定时任务，这个文件内容将不为空
function Diff_Cron {
  if [ -f ${ListCron} ]; then
    if [ -n "${JD_DIR}" ]
    then
      grep -E " j[drx]_\w+" ${ListCron} | perl -pe "s|.+ (j[drx]_\w+).*|\1|" | uniq | sort > ${ListTask}
    else
      grep "${ShellDir}/" ${ListCron} | grep -E " j[drx]_\w+" | perl -pe "s|.+ (j[drx]_\w+).*|\1|" | uniq | sort > ${ListTask}
    fi
    cat ${ListCronLxk} ${ListCronShylocks} | grep -E "j[drx]_\w+\.js" | perl -pe "s|.+(j[drx]_\w+)\.js.+|\1|" | sort > ${ListJs}
    grep -vwf ${ListTask} ${ListJs} > ${ListJsAdd}
    grep -vwf ${ListJs} ${ListTask} > ${ListJsDrop}
  else
    echo -e "${ListCron} 文件不存在，请先定义你自己的crontab.list...\n"
  fi
}

## 发送删除失效定时任务的消息
function Notify_DropTask {
  cd ${ShellDir}
  node update.js
  [ -f ${ContentDropTask} ] && rm -f ${ContentDropTask}
}

## 发送新的定时任务消息
function Notify_NewTask {
  cd ${ShellDir}
  node update.js
  [ -f ${ContentNewTask} ] && rm -f ${ContentNewTask}
}

## 检测配置文件版本
function Notify_Version {
  [ -f "${SendCount}" ] && [[ $(cat ${SendCount}) != ${VerConfSample} ]] && rm -f ${SendCount}
  UpdateDate=$(grep " Date: " ${FileConfSample} | awk -F ": " '{print $2}')
  UpdateContent=$(grep " Update Content: " ${FileConfSample} | awk -F ": " '{print $2}')
  if [ -f ${FileConf} ] && [[ "${VerConf}" != "${VerConfSample}" ]] && [[ ${UpdateDate} == $(date "+%Y-%m-%d") ]]
  then
    if [ ! -f ${SendCount} ]; then
      echo -e "检测到配置文件config.sh.sample有更新\n\n更新日期: ${UpdateDate}\n当前版本: ${VerConf}\n新的版本: ${VerConfSample}\n更新内容: ${UpdateContent}\n\n如需使用新功能按该文件前几行注释操作，否则请无视本消息。\n" | tee ${ContentVersion}
      echo -e "本消息只在该新版本配置文件更新当天发送一次，脚本地址：${ShellURL}" >> ${ContentVersion}
      cd ${ShellDir}
      node update.js
      if [ $? -eq 0 ]; then
        echo "${VerConfSample}" > ${SendCount}
        [ -f ${ContentVersion} ] && rm -f ${ContentVersion}
      fi
    fi
  else
    [ -f ${ContentVersion} ] && rm -f ${ContentVersion}
    [ -f ${SendCount} ] && rm -f ${SendCount}
  fi
}

## npm install 子程序，判断是否为安卓，判断是否安装有yarn
function Npm_InstallSub {
  if [ -n "${isTermux}" ]
  then
    npm install --no-bin-links || npm install --no-bin-links --registry=https://registry.npm.taobao.org
  elif ! type yarn >/dev/null 2>&1
  then
    npm install || npm install --registry=https://registry.npm.taobao.org
  else
    echo -e "检测到本机安装了 yarn，使用 yarn 替代 npm...\n"
    yarn install || yarn install --registry=https://registry.npm.taobao.org
  fi
}

#function Pip_InstallSub {
#  if [ -f $ScriptsDir3/requirements.txt ]; then
#    pip install -r requirements.txt
#  else
#    echo -e "\nrequirements.txt文件不存在\n"
#  fi
#}

## npm install scripts
function Npm_Install {
  cd ${ScriptsDir}
  if [[ "${PackageListOld}" != "$(cat package.json)" ]]; then
    echo -e "检测到package.json有变化，运行 npm install...\n"
    Npm_InstallSub
    if [ $? -ne 0 ]; then
      echo -e "\nnpm install 运行不成功，自动删除 ${ScriptsDir}/node_modules 后再次尝试一遍..."
      rm -rf ${ScriptsDir}/node_modules
    fi
    echo
  fi

  if [ ! -d ${ScriptsDir}/node_modules ]; then
    echo -e "运行 npm install...\n"
    Npm_InstallSub
    if [ $? -ne 0 ]; then
      echo -e "\nnpm install 运行不成功，自动删除 ${ScriptsDir}/node_modules...\n"
      echo -e "请进入 ${ScriptsDir} 目录后按照wiki教程手动运行 npm install...\n"
      echo -e "当 npm install 失败时，如果检测到有新任务或失效任务，只会输出日志，不会自动增加或删除定时任务...\n"
      echo -e "3...\n"
      sleep 1
      echo -e "2...\n"
      sleep 1
      echo -e "1...\n"
      sleep 1
      rm -rf ${ScriptsDir}/node_modules
    fi
  fi
}

## npm install scripts2
function Npm_Install2 {
  cd ${ScriptsDir2}
  if [[ "${PackageListOld2}" != "$(cat package.json)" ]]; then
    echo -e "检测到package.json有变化，运行 npm install...\n"
    Npm_InstallSub
    if [ $? -ne 0 ]; then
      echo -e "\nnpm install 运行不成功，自动删除 ${ScriptsDir2}/node_modules 后再次尝试一遍..."
      rm -rf ${ScriptsDir2}/node_modules
    fi
    echo
  fi

  if [ ! -d ${ScriptsDir2}/node_modules ]; then
    echo -e "运行 npm install...\n"
    Npm_InstallSub
    if [ $? -ne 0 ]; then
      echo -e "\nnpm install 运行不成功，自动删除 ${ScriptsDir2}/node_modules...\n"
      echo -e "请进入 ${ScriptsDir2} 目录后按照wiki教程手动运行 npm install...\n"
      echo -e "当 npm install 失败时，如果检测到有新任务或失效任务，只会输出日志，不会自动增加或删除定时任务...\n"
      echo -e "3...\n"
      sleep 1
      echo -e "2...\n"
      sleep 1
      echo -e "1...\n"
      sleep 1
      rm -rf ${ScriptsDir2}/node_modules
    fi
  fi
}

## pip install scripts3
#function Pip_Install {
#  cd ${ScriptsDir3}
#  if [[ "${PackageListOld3}" != "$(cat requirements.txt)" ]]; then
#    echo -e "检测到requirements.txt有变化，运行 pip install...\n"
#    Pip_InstallSub
#    if [ $? -ne 0 ]; then
#      echo -e "\npip install 运行不成功，再次尝试一遍..."
#      Pip_InstallSub
#    fi
#    echo
#  fi
#}

## 输出是否有新的定时任务
function Output_ListJsAdd {
  if [ -s ${ListJsAdd} ]; then
    echo -e "检测到有新的定时任务：\n"
    cat ${ListJsAdd}
    echo
  fi
}

## 输出是否有失效的定时任务
function Output_ListJsDrop {
  if [ ${ExitStatusScripts} -eq 0 ] && [ -s ${ListJsDrop} ]; then
    echo -e "检测到有失效的定时任务：\n"
    cat ${ListJsDrop}
    echo
  fi
}

## 自动删除失效的脚本与定时任务，需要5个条件：1.AutoDelCron 设置为 true；2.正常更新js脚本，没有报错；3.js-drop.list不为空；4.crontab.list存在并且不为空；5.已经正常运行过npm install
## 检测文件：LXK0301/jd_scripts 仓库中的 docker/crontab_list.sh，和 shylocks/Loon 仓库中的 docker/crontab_list.sh
## 如果检测到某个定时任务在上述检测文件中已删除，那么在本地也删除对应定时任务
function Del_Cron {
  if [ "${AutoDelCron}" = "true" ] && [ -s ${ListJsDrop} ] && [ -s ${ListCron} ] && [ -d ${ScriptsDir}/node_modules ]; then
    echo -e "开始尝试自动删除定时任务如下：\n"
    cat ${ListJsDrop}
    echo
    JsDrop=$(cat ${ListJsDrop})
    for Cron in ${JsDrop}
    do
      perl -i -ne "{print unless / ${Cron}( |$)/}" ${ListCron}
    done
    crontab ${ListCron}
    echo -e "成功删除失效的脚本与定时任务，当前的定时任务清单如下：\n\n--------------------------------------------------------------\n"
    crontab -l
    echo -e "\n--------------------------------------------------------------\n"
    if [ -d ${ScriptsDir}/node_modules ]; then
      echo -e "成功删除失效的定时任务：\n\n${JsDrop}\n\n脚本地址：${ShellURL}" > ${ContentDropTask}
      Notify_DropTask
    fi
  fi
}

## 自动增加新的定时任务，需要5个条件：1.AutoAddCron 设置为 true；2.正常更新js脚本，没有报错；3.js-add.list不为空；4.crontab.list存在并且不为空；5.已经正常运行过npm install
## 检测文件：LXK9301/jd_scripts 仓库中的 docker/crontab_list.sh，和 shylocks/Loon 仓库中的 docker/crontab_list.sh
## 如果检测到检测文件中增加新的定时任务，那么在本地也增加
## 本功能生效时，会自动从检测文件新增加的任务中读取时间，该时间为北京时间
function Add_Cron {
  if [ "${AutoAddCron}" = "true" ] && [ -s ${ListJsAdd} ] && [ -s ${ListCron} ] && [ -d ${ScriptsDir}/node_modules ]; then
    echo -e "开始尝试自动添加定时任务如下：\n"
    cat ${ListJsAdd}
    echo
    JsAdd=$(cat ${ListJsAdd})

    for Cron in ${JsAdd}
    do
      if [[ ${Cron} == jd_bean_sign ]]
      then
        echo "4 0,9 * * * bash ${ShellJd} ${Cron}" >> ${ListCron}
      else
        cat ${ListCronLxk} | grep -E "\/${Cron}\." | perl -pe "s|(^.+)node */scripts/(j[drx]_\w+)\.js.+|\1bash ${ShellJd} \2|" >> ${ListCron}
      fi
    done

    if [ $? -eq 0 ]
    then
      crontab ${ListCron}
      echo -e "成功添加新的定时任务，当前的定时任务清单如下：\n\n--------------------------------------------------------------\n"
      crontab -l
      echo -e "\n--------------------------------------------------------------\n"
      if [ -d ${ScriptsDir}/node_modules ]; then
        echo -e "jd-base脚本成功添加新的定时任务：\n\n${JsAdd}\n\n脚本地址：${ShellURL}" > ${ContentNewTask}
        Notify_NewTask
      fi
    else
      echo -e "添加新的定时任务出错，请手动添加...\n"
      if [ -d ${ScriptsDir}/node_modules ]; then
        echo -e "jd-base脚本尝试自动添加以下新的定时任务出错，请手动添加：\n\n${JsAdd}" > ${ContentNewTask}
        Notify_NewTask
      fi
    fi
  fi
}

## 在日志中记录时间与路径
echo -e "\n--------------------------------------------------------------\n"
echo -n "系统时间："
echo $(date "+%Y-%m-%d %H:%M:%S")
if [ "${TZ}" = "UTC" ]; then
  echo
  echo -n "北京时间："
  echo $(date -d "8 hour" "+%Y-%m-%d %H:%M:%S")
fi
echo -e "\nSHELL脚本目录：${ShellDir}\n"
echo -e "JS脚本目录：${ScriptsDir}\n"
echo -e "--------------------------------------------------------------\n"

## 更新shell脚本、检测配置文件版本并将sample/config.sh.sample复制到config目录下
Git_PullShell && Update_Cron
VerConfSample=$(grep " Version: " ${FileConfSample} | perl -pe "s|.+v((\d+\.?){3})|\1|")
[ -f ${FileConf} ] && VerConf=$(grep " Version: " ${FileConf} | perl -pe "s|.+v((\d+\.?){3})|\1|")
if [ ${ExitStatusShell} -eq 0 ]
then
  echo -e "\nshell脚本更新完成...\n"
  if [ -n "${JD_DIR}" ] && [ -d ${ConfigDir} ]; then
    cp -f ${FileConfSample} ${ConfigDir}/config.sh.sample
  fi
else
  echo -e "\nshell脚本更新失败，请检查原因后再次运行git_pull.sh，或等待定时任务自动再次运行git_pull.sh...\n"
fi

## 更新crontab
[[ $(date "+%-H") -le 2 ]] && Update_Cron

## 克隆或更新js脚本
if [ ${ExitStatusShell} -eq 0 ]; then
  echo -e "--------------------------------------------------------------\n"
  [ -f ${ScriptsDir}/package.json ] && PackageListOld=$(cat ${ScriptsDir}/package.json)
  [ -f ${ScriptsDir2}/package.json ] && PackageListOld2=$(cat ${ScriptsDir2}/package.json)
  #[ -f ${ScriptsDir3}/requirements.txt ] && PackageListOld3=$(cat ${ScriptsDir3}/requirements.txt)
  [ -d ${ScriptsDir}/.git ] && Git_PullScripts || Git_CloneScripts
  [ -d ${ScriptsDir2}/.git ] && Git_PullScripts2 || Git_CloneScripts2
  #[ -d ${ScriptsDir3}/.git ] && Git_PullScripts3 || Git_CloneScripts3
fi

## 执行LXK9301各函数
if [[ ${ExitStatusScripts} -eq 0 ]]
then
  echo -e "LXK9301的js脚本更新完成...\n"
  Change_ALL
  [ -d ${ScriptsDir}/node_modules ] && Notify_Version
  Diff_Cron
  Npm_Install
  Output_ListJsAdd
  Output_ListJsDrop
  Del_Cron
  Add_Cron
else
  echo -e "LXK9301的js脚本更新失败，请检查原因或再次运行git_pull.sh...\n"
  Change_ALL
fi

## 执行AutoSignMachine各函数
if [[ ${ExitStatusScripts2} -eq 0 ]]
then
  echo -e "AutoSignMachine的js脚本更新完成...\n"
  [ -d ${ScriptsDir2}/node_modules ]
  Npm_Install2
else
  echo -e "AutoSignMachine的js脚本更新失败，请检查原因或再次运行git_pull.sh...\n"
fi

## 执行BiliExp各函数
#if [[ ${ExitStatusScripts3} -eq 0 ]]
#then
#  echo -e "BiliExp的js脚本更新完成...\n"
#  Pip_Install
#else
#  echo -e "BiliExp的js脚本更新失败，请检查原因或再次运行git_pull.sh...\n"
#fi

## 调用用户自定义的diy.sh
if [ "${EnableExtraShell}" = "true" ]; then
  if [ -f ${FileDiy} ]
  then
    . ${FileDiy}
  else
    echo -e "${FileDiy} 文件不存在，跳过执行DIY脚本...\n"
  fi
fi
