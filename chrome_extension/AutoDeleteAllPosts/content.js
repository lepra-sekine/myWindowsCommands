(() => {
  // X / Twitter のプロフィール画面だけを対象にする。
  // 個人情報をコードに埋め込まないため、一般的なユーザー名形式で判定する。
  const TARGET_HOSTS = ["twitter.com", "x.com"];
  const PROFILE_PATH_PATTERN = /^\/[A-Za-z0-9_]{1,15}\/?$/;

  // 実際のボタン文言は英語・日本語の両方が存在するため、
  // 削除操作の識別に使う文字列を複数パターンで持つ。
  const DELETE_TEXTS = [
    "delete post",
    "delete",
    "投稿を削除",
    "削除",
    "削除する"
  ];

  // DOM の更新には少し時間がかかるため、各操作の待機時間を分けている。
  // これにより、メニュー展開・確認ダイアログ表示・再描画のタイミングをずらせる。
  const SLOT_DELAY_MS = 1200;
  const MENU_DELAY_MS = 500;
  const CONFIRM_DELAY_MS = 700;
  const RELOAD_DELAY_MS = 10000;

/**
 * 現在のページが削除対象のプロフィール画面かどうかを判定する。
 *
 * @returns {boolean} X / Twitter のプロフィール URL であれば true、その他のページなら false
 * @throws {TypeError} location が未定義の場合を想定するが、通常のブラウザコンテキストでは発生しない
 */
  function isTargetPage() {
    const host = location.hostname.toLowerCase();
    if (!TARGET_HOSTS.some((value) => host === value || host.endsWith(`.${value}`))) {
      return false;
    }

    const path = (location.pathname || "/").replace(/\/+$/, "") || "/";
    if (!path || path === "/") {
      return false;
    }

    const blockedPaths = [
      "/home",
      "/explore",
      "/notifications",
      "/messages",
      "/compose",
      "/settings",
      "/login",
      "/signup",
      "/search",
      "/i"
    ];

    if (blockedPaths.includes(path.toLowerCase())) {
      return false;
    }

    return PROFILE_PATH_PATTERN.test(path);
  }

/**
 * 指定したミリ秒だけ待機して、UI の更新タイミングをずらす。
 *
 * @param {number} ms - 待機する時間（ミリ秒）
 * @returns {Promise<void>} 指定時間後に解決する Promise
 */
  function wait(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * 画面内の投稿が消えた後の再描画待ちのため、ページを再読み込みして次の投稿群を取得する。
   *
   * @returns {void} 何も返さず、ページを再読込する副作用を持つ
   */
  function scheduleReload() {
    if (window.__autoDeleteReloadScheduled) {
      return;
    }

    window.__autoDeleteReloadScheduled = true;
    setTimeout(() => {
      window.__autoDeleteReloadScheduled = false;
      location.reload();
    }, RELOAD_DELAY_MS);
  }

/**
 * 指定した DOM 要素から可読なテキストを抽出し、ボタンやメニュー項目の比較に使える形式に整える。
 *
 * @param {Element|null} target - 文字列を取り出したい要素
 * @returns {string} 空白を正規化した文字列。対象が null の場合は空文字を返す。
 */
  function getText(target) {
    if (!target) {
      return "";
    }
    // 連続した空白を1つに圧縮して、ボタンの文言を安定して比較できるようにする。
    return (target.textContent || "").replace(/\s+/g, " ").trim();
  }

/**
 * メニュー内から削除操作を探して返す。
 *
 * @param {Element} root - 削除候補を検索するメニュー要素
 * @returns {Element|null} 削除操作に一致したボタン。見つからない場合は null
 */
  function findDeleteAction(root) {
    const candidates = root.querySelectorAll('[role="menuitem"], button, [role="button"]');
    for (const candidate of candidates) {
      const text = getText(candidate).toLowerCase();
      if (DELETE_TEXTS.some((keyword) => text.includes(keyword))) {
        return candidate;
      }
    }
    return null;
  }

/**
 * 投稿カードからメニューボタンを取得する。
 *
 * @param {Element} postEl - メニューボタンを見つけたい投稿カード要素
 * @returns {Element|null} 見つかったメニューボタン。見つからなければ null
 */
  function findMenuButton(postEl) {
    const selectors = [
      'button[aria-label*="More"]',
      'button[aria-label*="もっと"]',
      'button[data-testid="caret"]',
      'button[data-testid="tweetMenu"]',
      '[data-testid="caret"]',
      '[data-testid="tweetMenu"]'
    ];

    for (const selector of selectors) {
      const button = postEl.querySelector(selector);
      if (button) {
        return button;
      }
    }

    const actionRow = postEl.querySelector('[data-testid="tweetActions"]');
    if (actionRow) {
      return actionRow.querySelector('button');
    }

    return null;
  }

/**
 * 現在の画面に存在する投稿カードを列挙する。
 *
 * @returns {Element[]} 投稿カードの配列。画面更新後に再探索して取得する。
 */
  function getPostCandidates() {
    const selectors = [
      'article[data-testid="tweet"]',
      'article[data-testid="cellInnerDiv"]',
      '[data-testid="cellInnerDiv"]'
    ];

    const posts = [];
    for (const selector of selectors) {
      for (const el of document.querySelectorAll(selector)) {
        if (el && !posts.includes(el)) {
          posts.push(el);
        }
      }
    }

    return posts.filter((postEl) => {
      const text = getText(postEl).toLowerCase();
      return text.length > 0;
    });
  }

/**
 * 投稿1件に対して、メニュー開示 → 削除 → 確認の手順を実行する。
 *
 * @param {Element} postEl - 削除対象の投稿カード要素
 * @returns {Promise<boolean>} 削除に成功した場合は true、UI が見つからなかった場合は false
 */
  async function deleteCurrentPost(postEl) {
    const menuButton = findMenuButton(postEl);
    if (!menuButton) {
      return false;
    }

    menuButton.click();
    await wait(MENU_DELAY_MS);

    const menu = document.querySelector('[role="menu"], [data-testid="DropdownMenu"]');
    if (!menu) {
      return false;
    }

    const deleteAction = findDeleteAction(menu);
    if (!deleteAction) {
      return false;
    }

    deleteAction.click();
    await wait(CONFIRM_DELAY_MS);

    const confirmButton =
      document.querySelector('[data-testid="confirmationSheetConfirm"]') ||
      [...document.querySelectorAll('button, [role="button"]')].find((button) => {
        const text = getText(button).toLowerCase();
        return DELETE_TEXTS.some((keyword) => text.includes(keyword));
      });

    if (!confirmButton) {
      return false;
    }

    confirmButton.click();
    await wait(SLOT_DELAY_MS);
    return true;
  }

/**
 * プロフィール画面に残っている投稿を、削除できなくなるまで繰り返し処理する。
 *
 * @returns {Promise<void>} 何も返さず、削除完了または再読込の副作用を持つ
 */
  async function autoDeleteProfilePosts() {
    if (!isTargetPage()) {
      return;
    }

    while (true) {
      const posts = getPostCandidates();
      if (!posts.length) {
        console.log("[Auto Delete Posts] 投稿が見つからないため、プロフィールを再読み込みします。")
        scheduleReload();
        return;
      }

      const targetPost = posts[0];
      const didDelete = await deleteCurrentPost(targetPost);
      if (!didDelete) {
        console.log("[Auto Delete Posts] 削除対象を検出できなかったため、処理を終了します。")
        return;
      }

      await wait(SLOT_DELAY_MS);

      const remainingPosts = getPostCandidates();
      if (!remainingPosts.length) {
        console.log("[Auto Delete Posts] 1画面内の投稿がすべて削除されたため、再読み込みします。")
        scheduleReload();
        return;
      }
    }
  }

/**
 * 初回読み込み時に対象ページなら削除ループを開始する。
 *
 * @returns {void} 削除処理の開始時にのみ副作用を持つ
 */
  const start = () => {
    if (!isTargetPage()) {
      return;
    }

    autoDeleteProfilePosts();
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, { once: true });
  } else {
    start();
  }

  // DOMが更新されるたびに再度削除を試みる。
  // ただし同時に何度も走らないよう、簡単なガードを入れる。
  let scheduled = false;
  const observer = new MutationObserver(() => {
    if (!isTargetPage() || scheduled) {
      return;
    }

    scheduled = true;
    setTimeout(() => {
      scheduled = false;
      autoDeleteProfilePosts();
    }, 2000);
  });

  observer.observe(document.body || document.documentElement, {
    childList: true,
    subtree: true,
    attributes: true
  });
})();
