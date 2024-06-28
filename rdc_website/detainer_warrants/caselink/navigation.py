import re
import requests
from requests.adapters import HTTPAdapter
import urllib
from urllib3.util.retry import Retry
from flask import current_app

session = requests.Session()
retry = Retry(connect=3, backoff_factor=0.5)
adapter = HTTPAdapter(max_retries=retry)
session.mount("http://", adapter)
session.mount("https://", adapter)


class Navigation:

    APP_ID = "davlvp"
    BASE = "https://caselink.nashville.gov"
    BROWSER = "C*Chrome*124.0*Mac*NOBLOCKTEST"
    CASE_TYPE = "P_31"
    CGI_SCRIPT = "webshell.asp"
    FORM_ENCODED = "application/x-www-form-urlencoded"
    WEBSHELL_PATH = "/cgi-bin/webshell.asp"
    PDF_VIEWER_PATH = "/imageviewer.php"
    HEADERS = {
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
        "Accept-Language": "en-US,en;q=0.9",
        "Connection": "keep-alive",
        "Sec-Fetch-Mode": "navigate",
        "Sec-Fetch-Site": "same-origin",
        "Sec-Fetch-User": "?1",
        "Upgrade-Insecure-Requests": "1",
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "sec-ch-ua": '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
        "sec-ch-ua-mobile": "?0",
        "sec-ch-ua-platform": '"macOS"',
    }
    CASELINK_PROCESS = "CASELINK.MAIN"
    DATA = {"APPID": APP_ID, "CURRPROCESS": CASELINK_PROCESS}
    COOKIES = {
        "tktupdate": "",
    }
    POSTBACK_PATH_REGEX = re.compile(
        r"(?:self\.location\s*=\s*\")(.+?\.html)\"", re.MULTILINE
    )
    START_DATE_ITEM = "P_26"
    SEP = "%7F"

    def __init__(self, path):
        postback_parts = path.removeprefix("/gsapdfs/").split(".")[:-1]
        self.path = path
        self.web_io_handle = postback_parts[0]
        self.parent = postback_parts[1]

    def url(self):
        return Navigation._url(self.path)

    @classmethod
    def webshell(cls):
        return cls._url(cls.WEBSHELL_PATH)

    @classmethod
    def _extract_postback_url(cls, response):
        return re.search(cls.POSTBACK_PATH_REGEX, response.text)[1]

    @classmethod
    def _url(cls, path):
        return "{}{}".format(Navigation.BASE, path)

    @classmethod
    def merge_headers(cls, more_headers=None):
        if more_headers is None:
            return cls.HEADERS
        return {**cls.HEADERS, **more_headers}

    @classmethod
    def merge_data(cls, data):
        return {**cls.DATA, **data}

    @classmethod
    def from_response(cls, response):
        return cls(Navigation._extract_postback_url(response))

    @classmethod
    def _username(cls):
        return current_app.config["CASELINK_USERNAME"]

    @classmethod
    def _password(cls):
        return current_app.config["CASELINK_PASSWORD"]

    @classmethod
    def login(cls):
        headers = cls.merge_headers(
            {
                "Cache-Control": "max-age=0",
                "Content-Type": cls.FORM_ENCODED,
                "Origin": cls.BASE,
                "Referer": cls._url("//davlvplogin.html?123"),
                "Sec-Fetch-Dest": "frame",
            }
        )

        data = {
            "GATEWAY": "GATEWAY",
            "CGISCRIPT": cls.CGI_SCRIPT,
            "XEVENT": "VERIFY",
            "WEBIOHANDLE": "1714928640773",
            "BROWSER": cls.BROWSER,
            "MYPARENT": "px",
            "APPID": cls.APP_ID,
            "WEBWORDSKEY": "SAMPLE",
            "DEVPATH": "/INNOVISION/DEVELOPMENT/LVP.DEV",
            "OPERCODE": cls._username(),
            "PASSWD": cls._password(),
        }

        response = session.post(
            cls.webshell(), cookies=cls.COOKIES, headers=headers, data=data
        )

        return cls.from_response(response)

    def _submit_form(self, data, headers=None):
        merged_headers = self.merge_headers(
            {
                "Cache-Control": "max-age=0",
                "Content-Type": Navigation.FORM_ENCODED,
                "Origin": Navigation.BASE,
                "Referer": self.url(),
                "Sec-Fetch-Dest": "iframe",
            }
        )
        return session.post(
            self.webshell(),
            cookies=Navigation.COOKIES,
            headers={**merged_headers, **headers} if headers else merged_headers,
            data=data,
        )

    @classmethod
    def _format_date(cls, date):
        return urllib.parse.quote(date.strftime("%m/%d/%Y"), safe="")

    @classmethod
    def _encode_data(self, data):
        return urllib.parse.urlencode(data, safe="*")

    def add_start_date(self, start):
        start_date = Navigation._format_date(start)
        data = self.merge_data(
            {
                "CODEITEMNM": self.START_DATE_ITEM,
                "CURRVAL": start_date,
                "DEVPATH": "/INNOVISION/DEVELOPMENT/LVP.DEV",
                "FINDDEFKEY": "CASELINK.MAIN",
                "GATEWAY": "PB,NOLOCK,1,1",
                "LINENBR": "0",
                "NEEDRECORDS": "1",
                "OPERCODE": self._username(),
                "PARENT": "STDHUB*update",
                "STDID": "52832",
                "STDURL": "/caselink_4_4.davlvp_blank.html",
                "TARGET": "postback",
                "WEBIOHANDLE": self.web_io_handle,
                "WINDOWNAME": "update",
                "XEVENT": "POSTBACK",
                "CHANGED": "2",
                "CURRPANEL": "1",
                "HUBFILE": "USER_SETTING",
                "NPKEYS": "0",
                "SUBMITCOUNT": "4",
                "WEBEVENTPATH": "/GSASYS/TKT/TKT.ADMIN/WEB_EVENT",
                "WCVARS": "self.START_DATE_ITEM" + self.SEP,
                "WCVALS": start_date + self.SEP,
            }
        )
        return self._submit_form(
            self._encode_data(data),
            headers={
                "Host": "caselink.nashville.gov",
                "Accept-Encoding": "gzip, deflate, br, zstd",
            },
        )

    def add_detainer_warrant_type(self, end):
        data = self.merge_data(
            {
                "CODEITEMNM": self.CASE_TYPE,
                "CURRVAL": "2",
                "DEVPATH": "/INNOVISION/DEVELOPMENT/LVP.DEV",
                "FINDDEFKEY": self.CASELINK_PROCESS,
                "GATEWAY": "PB,NOLOCK,1,1",
                "LINENBR": "0",
                "NEEDRECORDS": "1",
                "OPERCODE": self._username(),
                "PARENT": "STDHUB*update",
                "STDID": "52832",
                "STDURL": "/caselink_4_4.davlvp_blank.html",
                "TARGET": "postback",
                "WEBIOHANDLE": self.web_io_handle,
                "WINDOWNAME": "update",
                "XEVENT": "POSTBACK",
                "CHANGED": "4",
                "CURRPANEL": "1",
                "HUBFILE": "USER_SETTING",
                "NPKEYS": "0",
                "SUBMITCOUNT": "5",
                "WEBEVENTPATH": "/GSASYS/TKT/TKT.ADMIN/WEB_EVENT",
                "WCVARS": "P_27{sep}P_31{sep}".format(sep="\x7f"),
                "WCVALS": "{end_date}{sep}{warrant_filter}{sep}".format(
                    end_date=Navigation._format_date(end),
                    warrant_filter="2",
                    sep="\x7f",
                ),
            }
        )

        return self._submit_form(
            self._encode_data(data), headers={"Host": "caselink.nashville.gov"}
        )

    def search(self):
        data = self.merge_data(
            {
                "CODEITEMNM": "WTKCB_20",
                "CURRVAL": "�� Search for Case(s)� ",
                "DEVPATH": "/INNOVISION/DEVELOPMENT/LVP.DEV",
                "FINDDEFKEY": self.CASELINK_PROCESS,
                "GATEWAY": "PB,NOLOCK,1,1",
                "LINENBR": "0",
                "NEEDRECORDS": "1",
                "OPERCODE": self._username(),
                "PARENT": "STDHUB*update",
                "STDID": "52832",
                "STDURL": "/caselink_4_4.davlvp_blank.html",
                "TARGET": "postback",
                "WEBIOHANDLE": self.web_io_handle,
                "WINDOWNAME": "update",
                "XEVENT": "POSTBACK",
                "CHANGED": "4",
                "CURRPANEL": "1",
                "HUBFILE": "USER_SETTING",
                "NPKEYS": "0",
                "SUBMITCOUNT": "6",
                "WEBEVENTPATH": "/GSASYS/TKT/TKT.ADMIN/WEB_EVENT",
                "WCVARS": "\x7f",
                "WCVALS": "\x7f",
            }
        )
        return self._submit_form(self._encode_data(data))

    def search_update(self, wc_vars, wc_values):
        data = self.merge_data(
            {
                "CODEITEMNM": "WTKCB_20",
                "CURRPROCESS": "CASELINK.MAIN",
                "CURRVAL": "�� Search for Case(s)� ",
                "DEVPATH": "/INNOVISION/DEVELOPMENT/LVP.DEV",
                "FINDDEFKEY": "CASELINK.MAIN",
                "GATEWAY": "PB,NOLOCK,1,1",
                "LINENBR": "0",
                "NEEDRECORDS": "1",
                "OPERCODE": self._username(),
                "PARENT": "STDHUB*update",
                "STDID": "52832",
                "STDURL": "/caselink_4_4.davlvp_blank.html",
                "TARGET": "postback",
                "WEBIOHANDLE": self.web_io_handle,
                "WINDOWNAME": "update",
                "XEVENT": "POSTBACK",
                "CHANGED": "4",
                "CURRPANEL": "1",
                "HUBFILE": "USER_SETTING",
                "NPKEYS": "0",
                "SUBMITCOUNT": "6",
                "WEBEVENTPATH": "/GSASYS/TKT/TKT.ADMIN/WEB_EVENT",
                "WCVARS": wc_vars,
                "WCVALS": wc_values,
            }
        )
        return self._submit_form(self._encode_data(data))

    def follow_url(self):
        return session.get(
            self.url(),
            cookies=Navigation.COOKIES,
            headers=self.merge_headers(
                {"Referer": self.url(), "Sec-Fetch-Dest": "frame"}
            ),
        )

    def menu(self):
        data = "APPID=davlvp&CODEITEMNM=&CURRPROCESS=CASELINK.ADMIN&CURRVAL=&DEVAPPID=&DEVPATH=%2FINNOVISION%2FDEVELOPMENT%2FLVP.DEV&FINDDEFKEY=CASELINK.MAIN&GATEWAY=WIN*CASELINK.ADMIN&LINENBR=0&NEEDRECORDS=&OPERCODE=REDDOOR&PARENT=MENU&PREVVAL=&STDID=&STDURL=%2Fcaselink_4_4.davlvp_blank.html&TARGET=&WEBIOHANDLE={web_io_handle}&WINDOWNAME=update&XEVENT=STDHUB".format(
            web_io_handle=self.web_io_handle
        )

        return self._submit_form(data)

    def read_rec(self):
        data = "APPID=davlvp&CODEITEMNM=&CURRPROCESS=CASELINK.MAIN&CURRVAL=1&DEVAPPID=&DEVPATH=%2FINNOVISION%2FDEVELOPMENT%2FLVP.DEV&FINDDEFKEY=CASELINK.MAIN&GATEWAY=FL&LINENBR=0&NEEDRECORDS=-1&OPERCODE=REDDOOR&PARENT=STDHUB*update&PREVVAL=0&STDID=52832&STDURL=%2Fcaselink_4_4.davlvp_blank.html&TARGET=postback&WEBIOHANDLE={web_io_handle}&WINDOWNAME=update&XEVENT=READREC&CHANGED=0&CURRPANEL=1&HUBFILE=USER_SETTING&NPKEYS=0&SUBMITCOUNT=2&WEBEVENTPATH=%2FGSASYS%2FTKT%2FTKT.ADMIN%2FWEB_EVENT&WCVARS=&WCVALS=".format(
            web_io_handle=self.web_io_handle
        )

        return self._submit_form(data)

    def open_advanced_search(self):
        data = "APPID=davlvp&CODEITEMNM=WTKCB_S1&CURRPROCESS=CASELINK.MAIN&CURRVAL=INVISIBLE&DEVAPPID=&DEVPATH=%2FINNOVISION%2FDEVELOPMENT%2FLVP.DEV&FINDDEFKEY=CASELINK.MAIN&GATEWAY=PB%2CNOLOCK%2C1%2C0&LINENBR=0&NEEDRECORDS=1&OPERCODE=REDDOOR&PARENT=STDHUB*update&PREVVAL=&STDID=52832&STDURL=%2Fcaselink_4_4.davlvp_blank.html&TARGET=postback&WEBIOHANDLE={web_io_handle}&WINDOWNAME=update&XEVENT=POSTBACK&CHANGED=0&CURRPANEL=1&HUBFILE=USER_SETTING&NPKEYS=0&SUBMITCOUNT=3&WEBEVENTPATH=%2FGSASYS%2FTKT%2FTKT.ADMIN%2FWEB_EVENT&WCVARS=%7F&WCVALS=%7F".format(
            web_io_handle=self.web_io_handle
        )

        return self._submit_form(data)

    def open_case(self, code_item, docket_id):
        data = "APPID=davlvp&CODEITEMNM={code_item}&CURRPROCESS=CASELINK.MAIN&CURRVAL={docket_id}&DEVAPPID=&DEVPATH=%2FINNOVISION%2FDEVELOPMENT%2FLVP.DEV&FINDDEFKEY=CASELINK.MAIN&GATEWAY=PB%2CNOLOCK%2C1%2C0&LINENBR=0&NEEDRECORDS=1&OPERCODE=REDDOOR&PARENT=STDHUB*update&PREVVAL=%FCCLICK&STDID=52832&STDURL=%2Fcaselink_4_4.davlvp_blank.html&TARGET=postback&WEBIOHANDLE={web_io_handle}&WINDOWNAME=update&XEVENT=POSTBACK&CHANGED=564&CURRPANEL=2&HUBFILE=USER_SETTING&NPKEYS=0&SUBMITCOUNT=8&WEBEVENTPATH=%2FGSASYS%2FTKT%2FTKT.ADMIN%2FWEB_EVENT&WCVARS=%7F&WCVALS=%7F".format(
            web_io_handle=self.web_io_handle, code_item=code_item, docket_id=docket_id
        )

        return self._submit_form(
            data,
            headers={
                "Host": "caselink.nashville.gov",
                "Accept-Encoding": "gzip, deflate, br, zstd",
            },
        )

    @classmethod
    def _encode(cls, string):
        return urllib.parse.quote(string, safe="")

    def open_case_redirect(self, case_details):
        dev_path = Navigation._encode(case_details["dev_path"])
        data = "APPID=pubgs&CODEITEMNM=P_104_21&CURRPROCESS=CASELINK.MAIN&CURRVAL=05%252F08%252F2024&DEVAPPID=&DEVPATH={dev_path}&FINDDEFKEY={process}&GATEWAY=CP*CASELINK.MAIN&LINENBR=21&NEEDRECORDS=0&OPERCODE=REDDOOR&PARENT=STDHUB*update&PREVVAL=%25FCCLICK&STDID={docket_id}&STDURL=%252Fcaselink_4_4.davlvp_blank.html&TARGET=_self&WEBIOHANDLE={web_io_handle}&WINDOWNAME=update&XEVENT=STDHUB&CHANGED=948&CURRPANEL=2&HUBFILE=USER_SETTING&NPKEYS=0&SUBMITCOUNT=9&WEBEVENTPATH=%252FGSASYS%252FTKT%252FTKT.ADMIN%252FWEB_EVENT&WCVARS=&WCVALS=".format(
            web_io_handle=self.web_io_handle,
            dev_path=dev_path,
            docket_id=case_details["docket_id"],
            process=case_details["process"],
        )

        return Navigation.from_response(self._submit_form(data))

    def open_pleading_document_redirect(self, case_details):
        dev_path = Navigation._encode(case_details["dev_path"])
        data = "APPID=pubgs&CODEITEMNM=&CURRPROCESS=LVP.SES.INQUIRY&CURRVAL=1&DEVAPPID=&DEVPATH={dev_path}&FINDDEFKEY=LVP.SES.INQUIRY&GATEWAY=FL&LINENBR=0&NEEDRECORDS=-1&OPERCODE=REDDOOR&PARENT=STDHUB*update&PREVVAL=0&STDID=24GT4890&STDURL=%252Fcaselink_4_4.davlvp_blank.html&TARGET=postback&WEBIOHANDLE={web_io_handle}&WINDOWNAME=update&XEVENT=READREC&CHANGED=0&CURRPANEL=1&HUBFILE=TRANS&NPKEYS=0&SUBMITCOUNT=2&WEBEVENTPATH=%252FGSASYS%252FTKT%252FTKT.ADMIN%252FWEB_EVENT&WCVARS=&WCVALS=".format(
            web_io_handle=self.web_io_handle, dev_path=dev_path
        )

        return self._submit_form(data)

    def view_pdf(self, image_path):
        data = "image={image_path}".format(image_path=self._encode(image_path))

        return session.post(
            self._url(Navigation.PDF_VIEWER_PATH),
            cookies=Navigation.COOKIES,
            headers=self.merge_headers(
                {
                    "Cache-Control": "max-age=0",
                    "Content-Type": Navigation.FORM_ENCODED,
                    "Origin": Navigation.BASE,
                    "Referer": self.url(),
                    "Sec-Fetch-Dest": "iframe",
                    "Sec-Fetch-Dest": "document",
                }
            ),
            data=data,
        )
