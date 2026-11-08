package com.myhours.app;

import android.view.View;
import android.webkit.WebView;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onStart() {
        super.onStart();
        WebView webView = getBridge().getWebView();
        if (webView != null) {
            // 禁用 WebView 边缘弹性回弹，避免滑到顶/底时导航栏随页面一起弹动
            webView.setOverScrollMode(View.OVER_SCROLL_NEVER);
            // 数据安全：禁止 file:// 与内容访问，避免本机文件被 WebView 读取
            webView.getSettings().setAllowFileAccess(false);
            webView.getSettings().setAllowContentAccess(false);
        }
    }
}
