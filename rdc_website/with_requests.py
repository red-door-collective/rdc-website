import requests
import re

CASELINK_BASE = 'https://caselink.nashville.gov'
FORM_ENCODED = 'application/x-www-form-urlencoded'

def navigate(path):
    return '{}{}'.format(CASELINK_BASE, path)

def headers(more_headers):
    return {**common_headers, **more_headers}

WEBSHELL = navigate('/cgi-bin/webshell.asp')

cookies = {
    'tktupdate': '',
}

common_headers = {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
    'Accept-Language': 'en-US,en;q=0.9',
    'Connection': 'keep-alive',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'same-origin',
    'Sec-Fetch-User': '?1',
    'Upgrade-Insecure-Requests': '1',
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'sec-ch-ua': '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"macOS"',
}



example_path = '/gsapdfs/1714929163736.STDHUB.20580.61922142.html'
example_parts = example_path.removeprefix('/gsapdfs/').split('.')[:-1]
web_io_handle_example = example_parts[0]
parent_example = example_parts[1]

# maybe open advanced search?
# add date start

headers = {
    'Cache-Control': 'max-age=0',
    'Content-Type': FORM_ENCODED,
    'Origin': CASELINK_BASE,
    'Referer': postback_url,
    'Sec-Fetch-Dest': 'iframe'
}

data = 'APPID=davlvp&CODEITEMNM=P_26&CURRPROCESS=CASELINK.MAIN&CURRVAL=05%2F01%2F2024&DEVAPPID=&DEVPATH=%2FINNOVISION%2FDEVELOPMENT%2FLVP.DEV&FINDDEFKEY=CASELINK.MAIN&GATEWAY=PB%2CNOLOCK%2C1%2C1&LINENBR=0&NEEDRECORDS=1&OPERCODE=REDDOOR&PARENT={parent}*update&PREVVAL=&STDID=52832&STDURL=%2Fcaselink_4_4.davlvp_blank.html&TARGET=postback&WEBIOHANDLE={web_io_handle}&WINDOWNAME=update&XEVENT=POSTBACK&CHANGED=2&CURRPANEL=1&HUBFILE=USER_SETTING&NPKEYS=0&SUBMITCOUNT=4&WEBEVENTPATH=%2FGSASYS%2FTKT%2FTKT.ADMIN%2FWEB_EVENT&WCVARS=P_26%7F&WCVALS=05%2F01%2F2024%7F'.format(
    web_io_handle=web_io_handle,
    parent=parent
)

response = requests.post(WEBSHELL, cookies=cookies, headers=headers, data=data)

# add date end
# add detainer warrant type

headers = {
    'Cache-Control': 'max-age=0',
    'Content-Type': FORM_ENCODED,
    'Origin': CASELINK_BASE,
    'Referer': postback_url,
    'Sec-Fetch-Dest': 'iframe'
}

data = 'APPID=davlvp&CODEITEMNM=P_31&CURRPROCESS=CASELINK.MAIN&CURRVAL=2&DEVAPPID=&DEVPATH=%2FINNOVISION%2FDEVELOPMENT%2FLVP.DEV&FINDDEFKEY=CASELINK.MAIN&GATEWAY=PB%2CNOLOCK%2C1%2C1&LINENBR=0&NEEDRECORDS=1&OPERCODE=REDDOOR&PARENT={parent}*update&PREVVAL=&STDID=52832&STDURL=%2Fcaselink_4_4.davlvp_blank.html&TARGET=postback&WEBIOHANDLE={web_io_handle}&WINDOWNAME=update&XEVENT=POSTBACK&CHANGED=4&CURRPANEL=1&HUBFILE=USER_SETTING&NPKEYS=0&SUBMITCOUNT=5&WEBEVENTPATH=%2FGSASYS%2FTKT%2FTKT.ADMIN%2FWEB_EVENT&WCVARS=P_27%7FP_31%7F&WCVALS=05%2F03%2F2024%7F2%7F'.format(
    web_io_handle=web_io_handle, 
    parent=parent
    )

response = requests.post(WEBSHELL, cookies=cookies, headers=headers, data=data)

# search

headers = {
    'Cache-Control': 'max-age=0',
    'Content-Type': FORM_ENCODED,
    'Origin': CASELINK_BASE,
    'Referer': postback_url,
    'Sec-Fetch-Dest': 'iframe'
}

data = 'APPID=davlvp&CODEITEMNM=WTKCB_20&CURRPROCESS=CASELINK.MAIN&CURRVAL=%A0%A0+Search+for+Case%28s%29%A0+&DEVAPPID=&DEVPATH=%2FINNOVISION%2FDEVELOPMENT%2FLVP.DEV&FINDDEFKEY=CASELINK.MAIN&GATEWAY=PB%2CNOLOCK%2C1%2C1&LINENBR=0&NEEDRECORDS=1&OPERCODE=REDDOOR&PARENT={parent}*update&PREVVAL=&STDID=52832&STDURL=%2Fcaselink_4_4.davlvp_blank.html&TARGET=postback&WEBIOHANDLE={web_io_handle}&WINDOWNAME=update&XEVENT=POSTBACK&CHANGED=4&CURRPANEL=1&HUBFILE=USER_SETTING&NPKEYS=0&SUBMITCOUNT=6&WEBEVENTPATH=%2FGSASYS%2FTKT%2FTKT.ADMIN%2FWEB_EVENT&WCVARS=%7F&WCVALS=%7F'.format(
    web_io_handle=web_io_handle,
    parent=parent
)

response = requests.post(WEBSHELL, cookies=cookies, headers=headers, data=data)

search_results_postback_path = re.search(r'(?:self\.location=\")(.+?\.html)\"', response.text)[1]
search_results_postback_parts = search_results_postback_path.removeprefix('/gsapdfs/').split('.')[:-1]
web_io_handle = search_results_postback_parts[0]
parent = search_results_postback_parts[1]
search_results_postback_url = navigate(search_results_postback_path)

# navigate to search results

headers = {
    'Referer': WEBSHELL,
    'Sec-Fetch-Dest': 'iframe'
}

response = requests.get(search_results_postback_url, cookies=cookies, headers=headers)

# export results to csv

headers = {
    'Cache-Control': 'max-age=0',
    'Content-Type': FORM_ENCODED,
    'Origin': CASELINK_BASE,
    'Referer': postback_url,
    'Sec-Fetch-Dest': 'iframe'
}

data = 'APPID=davlvp&CODEITEMNM=WTKCB_8&CURRPROCESS=CASELINK.MAIN&CURRVAL=Export+List&DEVAPPID=&DEVPATH=%2FINNOVISION%2FDEVELOPMENT%2FLVP.DEV&FINDDEFKEY=CASELINK.MAIN&GATEWAY=PB%2CNOLOCK%2C1%2C1&LINENBR=0&NEEDRECORDS=1&OPERCODE=REDDOOR&PARENT={parent}*update&PREVVAL=&STDID=52832&STDURL=%2Fcaselink_4_4.davlvp_blank.html&TARGET=postback&WEBIOHANDLE={web_io_handle}&WINDOWNAME=update&XEVENT=POSTBACK&CHANGED=3505&CURRPANEL=2&HUBFILE=USER_SETTING&NPKEYS=0&SUBMITCOUNT=14&WEBEVENTPATH=%2FGSASYS%2FTKT%2FTKT.ADMIN%2FWEB_EVENT&WCVARS=%7F&WCVALS=%7F'.format(
    web_io_handle=web_io_handle,
    parent=parent
)

response = requests.post(WEBSHELL, cookies=cookies, headers=headers, data=data)


def login(username, password):
    headers = {
        'Cache-Control': 'max-age=0',
        'Content-Type': FORM_ENCODED,
        'Origin': CASELINK_BASE,
        'Referer': navigate('///davlvplogin.html?123'),
        'Sec-Fetch-Dest': 'frame'
    }

    data = 'GATEWAY=GATEWAY&CGISCRIPT=webshell.asp&FINDDEFKEY=&XEVENT=VERIFY&WEBIOHANDLE=1714928640773&BROWSER=C*Chrome*124.0*Mac*NOBLOCKTEST&MYPARENT=px&APPID=davlvp&WEBWORDSKEY=SAMPLE&DEVPATH=%2FINNOVISION%2FDEVELOPMENT%2FLVP.DEV&OPERCODE={username}&PASSWD={password}'.format(
        username=username,
        password=password
    )

    response = requests.post(WEBSHELL, cookies=cookies, headers=headers, data=data)

    return re.search(r'(?:self\.location=\")(.+?\.html)\"', response.text)[1]

    postback_path = re.search(r'(?:self\.location=\")(.+?\.html)\"', response.text)[1]
    postback_parts = postback_path.removeprefix('/gsapdfs/').split('.')[:-1]
    web_io_handle = postback_parts[0]
    parent = postback_parts[1]
    postback_url = navigate(postback_path)

    response = requests.get(
        postback_url,
        cookies=cookies,
        headers=headers({
        'Referer': WEBSHELL,
        'Sec-Fetch-Dest': 'frame',
        }),
    )
    

def search():
    pass

def download_search_results_csv():
    pass

def scrape_warrant_page():
    pass