<!DOCTYPE html>
<html lang="{{ config.language }}">
  <head>
    {%- include '_partial/head.swig' %}
    <title>{%- block title -%}{%- endblock -%}</title>
  </head>

  <body>
    {%- if theme.google_analytics -%}
    <!-- Google Tag Manager (noscript) -->
    <noscript><iframe src="https://www.googletagmanager.com/ns.html?id={{ theme.google_analytics }}"
    height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript>
    <!-- End Google Tag Manager (noscript) -->
    {%- endif -%}

    {%- include '_partial/slideout.swig' -%}
    <div class="container" id="mobile-panel">
      <header id="header" class="header">
        {%- include '_partial/header.swig' -%}
      </header>

      <main id="main" class="main">
        <div class="content-wrapper">
          <div id="content" class="content">
            {%- block content -%}{%- endblock -%}
          </div>
          {%- include '_partial/comments.swig' -%}
        </div>
      </main>

      <footer id="footer" class="footer">
        {%- include '_partial/footer.swig' -%}
      </footer>

      <div class="back-to-top" id="back-to-top">
        <i class="iconfont icon-up"></i>
      </div>
    </div>

    {%- include '_script/comments.swig' -%}

    {%- include '_script/libs.swig' -%}
    {%- include '_script/theme.swig' -%}
  </body>
</html>
