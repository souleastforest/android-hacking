'use strict';

setImmediate(function () {
  Java.perform(function () {
    const seen = {};

    function safeString(v) {
      try {
        if (v === null || v === undefined) return '';
        return String(v);
      } catch (_) {
        return '';
      }
    }

    function findToken(node) {
      if (!node || typeof node !== 'object') return null;
      if (node.eSimDownloadToken && typeof node.eSimDownloadToken === 'object') {
        return node.eSimDownloadToken;
      }
      if (Array.isArray(node)) {
        for (let i = 0; i < node.length; i++) {
          const hit = findToken(node[i]);
          if (hit) return hit;
        }
        return null;
      }
      const keys = Object.keys(node);
      for (let i = 0; i < keys.length; i++) {
        const hit = findToken(node[keys[i]]);
        if (hit) return hit;
      }
      return null;
    }

    function emitResult(token) {
      if (!token) return;
      const lpaString = safeString(token.lpaString);
      if (!lpaString || seen[lpaString]) return;
      seen[lpaString] = true;
      const result = {
        host: safeString(token.host),
        matchingId: safeString(token.matchingId),
        lpaString: lpaString
      };
      console.log('[LPA_RESULT] ' + JSON.stringify(result));
    }

    try {
      const ResponseBuilder = Java.use('okhttp3.Response$Builder');
      const build = ResponseBuilder.build.overload();
      build.implementation = function () {
        const resp = build.call(this);
        try {
          const req = resp.request();
          const url = safeString(req.url());
          if (url.indexOf('https://publicapi.giffgaff.com/gateway/graphql') === -1) {
            return resp;
          }
          const body = safeString(resp.peekBody(1024 * 1024).string());
          if (body.indexOf('eSimDownloadToken') === -1) {
            return resp;
          }
          const parsed = JSON.parse(body);
          const token = findToken(parsed);
          emitResult(token);
        } catch (e) {
          console.log('[HOOK_ERROR] ' + e);
        }
        return resp;
      };
      console.log('[+] Hooked okhttp3.Response$Builder.build');
    } catch (e) {
      console.log('[-] Failed to hook okhttp3.Response$Builder.build: ' + e);
    }
  });
});
