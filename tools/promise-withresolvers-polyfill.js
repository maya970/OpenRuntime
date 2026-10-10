/* OpenRuntime — polyfill for Electron/Node < 22 (Win7 Clash 等)
 * Promise.withResolvers 在旧引擎不存在，启动前注入可消除：
 *   TypeError: Promise.withResolvers is not a function
 */
(function () {
  if (typeof Promise === 'undefined') return;
  if (typeof Promise.withResolvers === 'function') return;
  Promise.withResolvers = function withResolvers() {
    var resolve, reject;
    var promise = new Promise(function (res, rej) {
      resolve = res;
      reject = rej;
    });
    return { promise: promise, resolve: resolve, reject: reject };
  };
})();
