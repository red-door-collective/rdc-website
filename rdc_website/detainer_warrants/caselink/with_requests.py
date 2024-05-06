import requests
import re


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

