{%- if page.comments and is_post() -%}
  <div class="comments" id="comments">
    {%- if theme.disqus_shortname -%}
      <div id="disqus_thread">
        <noscript>
          Please enable JavaScript to view the
          <a href="//disqus.com/?ref_noscript">comments powered by Disqus.</a>
        </noscript>
      </div>
    {%- elif theme.livere_datauid -%}
      <div id="lv-container" data-id="city" data-uid="{{ theme.livere_datauid }}">
        <noscript>为正常使用来必力评论功能请激活JavaScript</noscript>
      </div>
    {%- elif theme.gitalk.enable -%}
      <div id="gitalk-container"></div>
    {%- elif theme.utterances.enable -%}
      <div id="utterances-container"></div>
    {%- elif theme.leancloud.app_id and theme.leancloud.app_key -%}
      <script src='//unpkg.com/valine/dist/Valine.min.js'></script>
      <div id="valine-container"></div>
      <script>
        var notify = {{ theme.valine.notify }} == true ? true : false;
        var verify = {{ theme.valine.verify }} == true ? true : false;
        var visitor = {{ theme.valine.visitor }} == true ? true : false;
        new Valine({
          el: '#valine-container',
          notify: notify,
          verify: verify,
          appId: '{{ theme.leancloud.app_id }}',
          appKey: '{{ theme.leancloud.app_key }}',
          lang: '{{ theme.valine.lang }}',
          placeholder: '{{ theme.valine.placeholder }}',
          avatar: '{{ theme.valine.avatar }}',
          pageSize: {{ theme.valine.pageSize }},
          recordIP: {{ theme.valine.recordIP }},
          visitor: visitor
        });
       </script>
    {%- endif -%}
  </div>
{%- endif -%}
