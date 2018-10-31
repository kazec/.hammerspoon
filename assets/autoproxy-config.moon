{
  proxies:
    'reject': 'PROXY 127.0.0.1:8000'
    'socks':  'SOCKS5 127.0.0.1:1080; SOCKS 127.0.0.1:1080'
    'direct': 'DIRECT'
  rules:
    'adblock-main':
      'host': {
        'btrace.qq.com'
        'hm.baidu.com'
        'd0.sina.com.cn'
        'beacon.sina.com.cn'
        'mmstat.alicdn.com'
        'cb.baidu.com'
        'pos.baidu.com'
        'cbjs.baidu.com'
        'cpro.baidu.com'
        'drmcmm.baidu.com'
        'app.acm.dzwww.com'
        'strip.taobaocdn.com'
        'nsclick.baidu.com'
        'gemini.yahoo.com'
        'mobiledl.adobe.com'
      }
      'domain': {
        'googletagservices.com'
        'google-analytics.com'
        'talkingdata.net'
        'tagtic.cn'
        'cnzz.com'
        'mixpanel.com'
        'tanx.com'
        'umeng.com'
        'umeng.co'
        'umtrack.com'
        'youmi.net'
        'medialytics.com'
        'click.taobao.com'
        'doubleclick.net'
        'googlesyndication.com'
        'lianmeng.360.cn'
        'mmstat.com'
        'amazon-adsystem.com'
        'criteo.com'
        'admob.com'
        'adwhirl.com'
        'smaato.net'
        'saymedia.com'
        'vserv.mobi'
        'velti.com'
        'celtra.com'
        'jumptap.com'
        'applovin.com'
        'mobpartner.mobi'
        'adinfuse.com'
        'mydas.mobi'
        'adclick.lv'
        'tapad.com'
        'mojiva.com'
        'inmobi.com'
        'phluantmobile.net'
        'mojiva.com'
        'mocean.mobi'
        'smartadserver.com'
        'mobclix.com'
        'mdotm.com'
        'greystripe.com'
      }
    'adblock-keyword':
      'host-keyword': {
        '/(?:advert|analytic|syndicat|statistic|affiliate|tracker|tracking)/'
        '/(?:^|\\.-)(?:ad(?:v|server)?|stat|click|trace)s?\\d*(?:\\.-|$)/'
      }
      'url-keyword': {
        '/(?:analytic|analysis|\\w{3,5}lytic|ad|adv|advert|stat|quant|syndicate?|syndication|beacon|campaign|aff|affiliate|track\\w\\-{0,5})s?\\d*\\.(:?js|min)/'
        '/\\._\\-\\/(?:banner|popup|ad|adv|advert|stat)s?\\d*(?:\\._\\-\\/|$)/'
      }
    'black':
      'host': {
        'zh.wikipedia.org'
        'gist.github.com'
        'codeload.github.com'
      }
      'domain': {
        'google.com'
        'twitter.com'
        'twimg.com'
        'youtube.com'
        'ytimg.com'
        'googlevideo.com'
        'googleapis.com'
        'ggpht.com'
        'gstatic.com'
        'amazonaws.com'
      }
    'intranet':
      'net': {
        '0.0.0.0/8'
        '10.0.0.0/8'
        '100.64.0.0/10'
        '127.0.0.0/8'
        '169.254.0.0/16'
        '172.16.0.0/12'
        '192.0.0.0/29'
        '192.0.2.0/24'
        '192.88.99.0/24'
        '192.168.0.0/16'
        '198.18.0.0/15'
        '198.51.100.0/24'
        '203.0.113.0/24'
        '224.0.0.0/4'
        '240.0.0.0/4'
        '255.255.255.255'
      }
      'domain': {
        'lan'
      }
    'white-oversea':
      'domain': {
        'exhentai.org'
        'imgur.com'
        'icloud.com'
        'inoreader.com'
        'wolframalpha.com'
        'wikipedia.com'
        'wikimedia.com'
      }
      'url-keyword': {
        '/keystamp=\\w-+;fileindex=\\d+;xres=/'
      }
    'white-cn':
      'host': {
        'space.bilibili.com'
      }
      'domain': {
        'nga.cn'
        'weibo.com'
        'miaopai.com'
        'a9vg.com'
        'acfun.tv'
        'qq.com'
        'douyu.com'
        'zhanqi.tv'
        'panda.tv'
        'huya.com'
        'lagou.com'
        'zhipin.com'
        'huomao.com'
        'mcbbs.net'
        'zhihu.com'
        '163.com'
        '178.com'
        '126.net'
        'psnine.com'
        'baidu.com'
        'bilibili.com'
        'sspai.com'
        'wanqu.co'
        'ngacn.cc'
        'nowcoder.com'
        'acgvideo.com'
        'gcores.com'
        'bytedance.com'
        'xiami.com'
        'v2ex.com'
        'kanquwen.com'
      }
      'url-keyword': {
        '/acgvideo\\.com/'
        '/live\\.panda/'
        '/douyucdn\\.cn/'
      }
    'white-res':
      'domain': {
        'sinaimg.cn'
        'alicdn.com'
        'aliyuncs.com'
        'bdstatic.com'
        'hdslb.com'
        'zhimg.com'
        'ourdvsss.com'
        'douyucdn.com'
        'd9vg.com'
        'zhimg.com'
        'ykimg.com'
        'pdim.gs'
        'typekit.com'
        'sinastorage.com'
        'xiami.net'
        'cdn-apple.com'
        '8686c.com'
        'bnbsky.com'
        'akamaihd.net'
        'steamusercontent.com'
        'mzstatic.com'
        'msstatic.com'
        -- 'githubusercontent.com'
        'cs.streampowered.com'
        'cloudflare.com'
        'sstatic.com'
      }
    'white-finacial':
      'domain': {
        '95516.com'
        'unionpay.com'
        'alipay.com'
        'alipaylog.com'
        'alipayobjects.com'
        'paypal.com'
        'tenpay.com'
        'taobao.com'
        'jd.com'
        'tmall.com'
      }
  profiles:
    auto:
      proxies:  { 'reject', 'socks', 'direct', 'socks' }
      'reject': { 'adblock-main', 'adblock-keyword' }
      'socks':  { 'black' }
      'direct': { 'intranet', 'white-oversea', 'white-cn', 'white-res', 'white-finacial' }
    direct:
      proxies:  { 'reject', 'socks', 'direct' }
      'reject': { 'adblock-main', 'adblock-keyword' }
      'socks':  { 'black' }
    proxy:
      proxies:  { 'direct', 'reject', 'socks' }
      'direct': { 'intranet' }
      'reject': { 'adblock-main', 'adblock-keyword' }
}
