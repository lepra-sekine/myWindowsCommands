function deletePost() {
    // 各投稿のメニューボタンを取得
    const btns = document.querySelector('button[data-testid=caret]');

    if (!btns) {
        return false;
    }

    // 1個目の投稿のメニューボタンをクリック
    btns[0].click();

    // メニューの削除ボタンクリック
    const dltBtn = document.querySelector('div[role=menu] div[role=menuitem]');
    dltBtn.click();

    // 確認ダイアログの削除クリック
    const confDialog = document.querySelector('div[data-testid=confirmationSheetDialog] div button[data-testid=confirmationSheetConfirm]');
    confDialog.click();
}


try {
    if (!deletePost()) {
        alert('削除する対象がありません。Chrome拡張から削除してください。');
    }
} catch (error) {
    console.error(error);
    alert('エラー');
}