# -*- coding: utf-8 -*-
from . import bili
import os, math, time, base64, re
from concurrent.futures import ThreadPoolExecutor
from threading import Lock

class VideoUploader(object):
    '''B站视频上传类'''
    def __init__(self, 
                 cookieData: dict, 
                 title: str = "", 
                 desc: str = "", 
                 dtime: int = 0, 
                 tag: list = [], 
                 copyright: int = 2, 
                 tid: int = 174, 
                 source: str = "", 
                 cover: str = "",
                 desc_format_id: int = 0, 
                 subtitle = {"open":0,"lan":""}
                 ):
        '''
        创建一个B站视频上传类
        cookieData     dict  账户cookie
        title          str   稿件标题
        desc           str   稿件简介
        dtime          int   延迟发布时间,最短4小时后,10位时间戳
        copyright      list  是否原创,原创取1,转载取2
        tid            int   稿件分区id,默认为174,生活其他分区
        source         str   非原创时需提供转载来源网址
        cover          str   稿件封面,图片url
        desc_format_id int
        subtitle       dict
        '''
        bili.__init__(self)
        if not bili.login_by_cookie(self, cookieData):
            raise ValueError('cookie无效')

        self._data = {
            "copyright":copyright,
            "videos":[],
            "source":source,
            "tid":tid, #分区,174为生活，其他分区
            "cover":cover, #封面图片，可由recovers方法得到视频的帧截图
            "title":title,
            "tag":"",
            "desc_format_id":desc_format_id,
            "desc":desc,
            "dynamic":"",
            "subtitle":subtitle
            }
        if dtime and dtime - int(time.time()) > 14400:
            self._data["dtime"] = dtime

        if tag:
            self.setTag(tag)

    def uploadFile(self, 
                   filepath: str, 
                   fsize: int = 8388608, 
                   ThreadNum: int = 3
                   ) -> dict:
        '''
        上传本地视频文件,返回视频信息
        filepath  str  视频路径
        fsize     int  视频分块大小,默认为8388608,没有必要请勿修改
        ThreadNum int  视频上传线程数,默认为3,没有必要请勿修改
        '''
        lock = Lock()
        def _upload_worker(fileobj, sn: int):
            lock.acquire() #读文件分块前先加锁
            fileobj.seek(sn*fsize)
            data = fileobj.read(fsize)
            lock.release()
            bili.videoUpload(self, url, auth, upload_id, data, sn, chunks, sn*fsize, size) #上传分块

        path, name = os.path.split(filepath)#分离路径与文件名
        preffix = os.path.splitext(name)[0]
        with open(filepath, 'rb') as f: 
            size = f.seek(0, 2) #获取文件大小
            chunks = math.ceil(size / fsize) #获取分块数量
            retobj = bili.videoPreupload(self, name, size) #申请上传
            auth = retobj["auth"] #验证信息
            endpoint = retobj["endpoint"]  #目标服务器，用于构建上传http url
            biz_id = retobj["biz_id"]
            upos_uri = retobj["upos_uri"][6:] #目标路径，用于构建上传http url
            rname = os.path.splitext(os.path.split(upos_uri)[-1])[0] #云端文件名,不带路径和后缀
            url = f'https:{endpoint}{upos_uri}'  #视频上传路径
            upload_id = bili.videoUploadId(self, url, auth)["upload_id"] #得到上传id

            threadPool = ThreadPoolExecutor(max_workers=ThreadNum, thread_name_prefix="upload_") #创建线程池
            parts = [] #分块信息
            for ii in range(chunks):
                parts.append({"partNumber":ii+1,"eTag":"etag"})
                threadPool.submit(_upload_worker, f, ii)
            threadPool.shutdown(wait=True)
        
        retobj = bili.videoUploadInfo(self, url, auth, parts, name, upload_id, biz_id)
        if (retobj["OK"] == 1):
            return {"title": preffix, "filename": rname, "desc": ""}
        return None

    def uploadFileOneThread(self, 
                            filepath: str, 
                            fsize: int = 8388608
                            ) -> dict:
        '''
        单线程上传本地视频文件,返回视频信息
        filepath  str  视频路径
        fsize     int  视频分块大小,默认为8388608,没有必要请勿修改
        '''
        path, name = os.path.split(filepath)#分离路径与文件名
        preffix = os.path.splitext(name)[0]
        with open(filepath, 'rb') as f: 
            size = f.seek(0, 2) #获取文件大小
            chunks = math.ceil(size / fsize) #获取分块数量
            retobj = bili.videoPreupload(self, name, size) #申请上传
            auth = retobj["auth"]
            endpoint = retobj["endpoint"]
            biz_id = retobj["biz_id"]
            upos_uri = retobj["upos_uri"][6:]
            rname = os.path.splitext(os.path.split(upos_uri)[-1])[0] #云端文件名,不带路径和后缀
            url = f'https:{endpoint}{upos_uri}'  #视频上传路径
            upload_id = bili.videoUploadId(self, url, auth)["upload_id"] #得到上传id

            #开始上传
            parts = [] #分块信息
            f.seek(0, 0)
            for i in range(chunks): #单线程分块上传，官方支持三线程
                data = f.read(fsize) #一次读取一个分块大小
                bili.videoUpload(self, url, auth, upload_id, data, i, chunks, i*fsize, size)#上传分块
                parts.append({"partNumber":i+1,"eTag":"etag"}) #添加分块信息，partNumber从1开始
        
        retobj = bili.videoUploadInfo(self, url, auth, parts, name, upload_id, biz_id)
        if (retobj["OK"] == 1):
            return {"title": preffix, "filename": rname, "desc": ""}
        return None

    def uploadCover(self, 
                    filepath: str
                    ) -> str:
        '''
        上传本地图片文件,返回图片url
        filepath str 本地图片路径
        '''
        suffix = os.path.splitext(filepath)[-1]
        with open(filepath,'rb') as f:
            code = base64.b64encode(f.read()).decode()
        return bili.videoUpcover(self, f'data:image/{suffix};base64,{code}')["data"]["url"].replace('http://', 'https://')

    def submit(self) -> dict:
        '''提交视频'''
        if self._data["title"] == "":
            self._data["title"] = self._data["videos"][0]["title"]
        self._submit = bili.videoAdd(self, self._data)
        return self._submit

    def delete(self) -> bool:
        '''立即撤销本视频的发布(会丢失硬币)，失败(有验证码)返回false'''
        aid = self._submit["data"]["aid"]
        retobj = bili.videoPre(self)
        challenge = retobj["data"]["challenge"]
        gt = retobj["data"]["gt"]
        return (self.videoDelete(self, aid, challenge, gt, f'{gt}%7Cjordan')["code"] == 0)

    def recovers(self, 
                 upvideo: dict
                 ) -> list:
        '''
        返回官方生成的封面,返回url列表,刚上传可能获取不到并返回空列表
        upvideo dict 由uploadFile方法返回的dict
        '''
        return bili.videoRecovers(self, upvideo["filename"])["data"]

    def getTags(self, 
                upvideo: dict
                ) -> list:
        '''
        返回官方推荐的tag列表
        upvideo dict 由uploadFile方法返回的dict
        '''
        return [x["tag"] for x in bili.videoTags(self, upvideo["title"], upvideo["filename"])["data"]]

    def add(self, 
            upvideo: dict
            ) -> None:
        '''
        添加已经上传的视频
        upvideo dict 由uploadFile方法返回的dict
        '''
        self._data["videos"].append(upvideo)

    def clear(self) -> None:
        '''清除已经添加的视频'''
        self._data["videos"] = []

    def setDtime(self, 
                 dtime: int
                 ) -> None:
        '''
        设置延时发布时间
        dtime int 10位时间戳,距离提交必须大于4小时
        '''
        if dtime - int(time.time()) > 14400:
            self._data["dtime"] = dtime

    def setTitle(self, 
                 title: str
                 ) -> None:
        '''
        设置标题
        title str 稿件标题
        '''
        self._data["title"] = title

    def setDesc(self, 
                desc: str
                ) -> None:
        '''
        设置简介
        desc str 稿件简介
        '''
        self._data["desc"] = desc

    def setTag(self, 
               tag: list = []
               ) -> None:
        '''
        设置标签
        tag list 标签字符串列表
        '''
        tagstr = ""
        dynamic = ""
        for i in range(len(tag)):
            if (i == len(tag) - 1):
                tagstr += tag[i]
            else:
                tagstr += f'{tag[i]},'
            dynamic += f'#{tag[i]}#'
        self._data["tag"] = tagstr
        self._data["dynamic"] = dynamic

    def setCopyright(self, 
                     copyright: int = 2
                     ) -> None:
        '''
        设置原创或转载
        copyright int 1表示原创，2表示转载
        '''
        self._data["copyright"] = copyright

    def setTid(self, 
               tid: int = 174
               ) -> None:
        '''
        设置视频分区
        tid int 分区id整数
        '''
        self._data["tid"] = tid

    def setSource(self, 
                  source: str
                  ) -> None:
        '''
        设置转载视频源地址
        source str 视频源地址
        '''
        self._data["source"] = source

    def setCover(self, 
                 cover: str
                 ) -> None:
        '''
        设置视频封面
        cover str 本地图片路径或http开头的图片url
        '''
        if not cover.startswith('http'):
            cover = self.uploadCover(cover)
        self._data["cover"] = cover

    def setDescFormatId(self, 
                        desc_format_id: int
                        ) -> None:
        '''
        设置desc_format_id
        desc_format_id int
        '''
        self._data["desc_format_id"] = desc_format_id

    def setSubtitle(self, 
                    subtitle: dict
                    ) -> None:
        '''
        设置subtitle
        subtitle dict
        '''
        self._data["subtitle"] = subtitle

class _videoStream(object):
    def __init__(self, name: str,url: str, resolution: str, size: int, cid: int):
        self._name = name
        self._url = url
        self._resolution = resolution
        self._size = size
        self._cid = cid

    def __repr__(self):
        return f'<name={self._name};resolution={self._resolution};size={self._size};cid={self._size}>'

    def __str__(self):
        return f'filename={self._name} ; resolution={self._resolution} ; size={self._size / 1024 / 1024:0.2f}MB'

    @property
    def url(self) -> str:
        '''返回下载流url'''
        return self._url

    @property
    def fliename(self) -> str:
        '''返回下载文件名'''
        return self._name

    @property
    def cid(self) -> int:
        '''返回视频cid'''
        return self._cid

class _videos(object):
    def __init__(self, subtitle, bvid='', cid=0, epid=''):
        self._title = subtitle.replace('/',' ')
        self._bvid = bvid
        self._cid = cid

    def __repr__(self):
        return f'<title={self._title};bvid={self._bvid};cid={self._cid}>'

    def __str__(self):
        return self._title

    def getTitle(self):
        '''获取当前视频标题'''
        return self._title

    def allStream(self, cookieData: dict = None, reverse_proxy='', force_use_proxy=False):
        '''
        获取所有视频流
        cookieData dict :包含"SESSDATA"值的字典，模拟用户登录
        reverse_proxy str :B站接口代理地址
        force_use_proxy bool :强制使用代理地址(默认请求失败才尝试代理地址)
        '''
        biliapi = bili()
        if cookieData:
            biliapi.login_by_cookie(cookieData)

        if force_use_proxy:
            RP = reverse_proxy
            data = biliapi.playerUrl(cid=self._cid, bvid=self._bvid, reverse_proxy=RP)
            if data["code"] != 0:
                raise Exception(f'解析失败，请尝试使用会员账号(错误信息：{data["message"]})')
        else:
            RP = ''
            data = biliapi.playerUrl(cid=self._cid, bvid=self._bvid, reverse_proxy=RP)
            if data["code"] != 0:
                if reverse_proxy == '':
                    raise Exception(f'解析失败，请尝试使用代理或会员账号(错误信息：{data["message"]})')
                else:
                    RP = reverse_proxy
                    data = biliapi.playerUrl(cid=self._cid, bvid=self._bvid, reverse_proxy=RP)
                    if data["code"] != 0:
                        print(self._bvid, self._cid)
                        raise Exception(f'解析失败，请尝试更换代理地区或使用会员账号(错误信息：{data["message"]})')
        
        accept_quality = data["data"]["accept_quality"]
        accept_description = data["data"]["accept_description"]
        ret = []
        for ii in range(len(accept_quality)):
            data = biliapi.playerUrl(cid=self._cid, bvid=self._bvid, qn=accept_quality[ii], reverse_proxy=RP)["data"]
            if data["quality"] != accept_quality[ii]:
                continue
            if 'flv' in data["format"]:
                ret.append(_videoStream(f'{self._title}.flv', data["durl"][0]["url"].replace('http:','https:'),accept_description[ii],data["durl"][0]["size"], self._cid))
            else:
                ret.append(_videoStream(f'{self._title}.mp4', data["durl"][0]["url"].replace('http:','https:'),accept_description[ii],data["durl"][0]["size"], self._cid))
        return ret

class VideoParser(object):
    '''B站视频解析类'''

    def __init__(self, url: str):
        self.parser(url)

    def all(self):
        '''取得当前所有视频(分P)'''
        if self._type == 1:
            list = bili.playList(self._bvid)["data"]
            return [_videos(x["part"], self._bvid, x["cid"]) for x in list]
        elif self._type == 2:
            return [_videos(x[0], x[1], x[2]) for x in self._eplist]
        else:
            return []

    def parser(self, url: str):
        '''
        解析视频
        url  str: BV，av，ep，ss号以及包含这些号的网址
        '''
        self._type = 0
        find = re.findall('(BV|av|ep|ss)([0-9 a-z A-Z]*)', url)
        if len(find):
            if find[0][0] == 'BV':
                self._bvid = f'BV{find[0][1]}'
                self._title = bili.webView(self._bvid)["data"]["title"]
                self._type = 1
            elif find[0][0] == 'av':
                self._bvid = bili.av2bv(int(find[0][1]))
                self._title = bili.webView(self._bvid)["data"]["title"]
                self._type = 1
            elif find[0][0] == 'ep' or find[0][0] == 'ss':
                data = bili.epPlayList(find[0][0] + find[0][1])
                self._title = data["mediaInfo"]["title"]
                self._eplist = [[f'{x["titleFormat"]} {x["longTitle"]}', x["bvid"], x["cid"]] for x in data["epList"]]
                for section in data["sections"]:
                    for x in section["epList"]:
                        self._eplist.append([f'{x["titleFormat"]} {x["longTitle"]}', x["bvid"], x["cid"]])
                self._type = 2
        else:
            raise Exception("不支持的参数")

    def getTitle(self):
        '''获取标题'''
        return self._title