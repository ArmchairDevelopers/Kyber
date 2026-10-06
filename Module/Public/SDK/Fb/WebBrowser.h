namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(LevelWebBrowserDescriptionComponent, 0x144615C70);
_KB_DECLARE_TYPEINFO(WebBrowserSettings, 0x144615CF0);
_KB_DECLARE_TYPEINFO(UIWebViewNotificationErrorMessage, 0x144615F30);
_KB_DECLARE_TYPEINFO(WebViewError, 0x144615EF0);
_KB_DECLARE_TYPEINFO(UIWebViewNotificationUrlChangedMessage, 0x144615F80);
_KB_DECLARE_TYPEINFO(UIWebViewRequestCloseViewMessage, 0x144615FD0);
_KB_DECLARE_TYPEINFO(UIWebViewRequestViewPageMessage, 0x144616020);
_KB_DECLARE_TYPEINFO(UIWebViewWidgetData, 0x144615D70);
_KB_DECLARE_TYPEINFO(WebBrowserBundleAsset, 0x144615DF0);
_KB_DECLARE_TYPEINFO(WebBrowserLocalURLAsset, 0x144615E70);
_KB_DECLARE_TYPEINFO(UIWebViewWidget, 0x144616070);

#undef _KB_DECLARE_TYPEINFO
}
