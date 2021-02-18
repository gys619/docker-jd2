from BiliClient import asyncbili
from .push_message_task import webhook
from .import_once import now_time
import logging

async def xlive_bag_send_task(biliapi: asyncbili,
                              task_config: dict = None
                              ) -> None:
    if task_config and task_config["room_id"]:
        room_id = task_config["room_id"]
    else:
        try:
            room_id = (await biliapi.xliveGetRecommendList())["data"]["list"][6]["roomid"]
        except Exception as e:
            logging.warning(f'{biliapi.name}: 获取直播间异常，原因为{str(e)}，跳过送出直播间礼物，建议手动指定直播间')
            webhook.addMsg('msg_simple', f'{biliapi.name}:直播送出礼物失败\n')
            return

    if task_config:
        expire = task_config.get("expire", 172800)
    else:
        expire = 172800

    try:
         uid = (await biliapi.xliveGetRoomInfo(room_id))["data"]["room_info"]["uid"]
         bagList = (await biliapi.xliveGiftBagList())["data"]["list"]
         ishave = False
         for x in bagList:
             if x["expire_at"] - now_time < expire and x["expire_at"] - now_time > 0: #礼物到期时间小于2天
                 ishave = True
                 ret = await biliapi.xliveBagSend(room_id, uid, x["bag_id"], x["gift_id"], x["gift_num"])
                 if ret["code"] == 0:
                     logging.info(f'{biliapi.name}: {ret["data"]["send_tips"]} {ret["data"]["gift_name"]} 数量{ret["data"]["gift_num"]}')
         if not ishave:
             logging.info(f'{biliapi.name}: 没有2天内过期的直播礼物，跳过赠送')
    except Exception as e:
        logging.warning(f'{biliapi.name}: 直播送出即将过期礼物异常，原因为{str(e)}')
        webhook.addMsg('msg_simple', f'{biliapi.name}:直播送出礼物失败\n')