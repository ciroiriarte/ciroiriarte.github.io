---
layout: page
title: Topics
permalink: /topics/
---
<ul class="topic-index">
{%- for t in site.data.taxonomy.topics -%}
  {%- assign topic_posts = site.posts | where_exp: "p", "p.categories contains t[0]" -%}
  {%- if topic_posts.size > 0 %}
  <li><a href="#{{ t[0] }}">{{ t[1].name | escape }}</a> <span class="count">{{ topic_posts.size }}</span></li>
  {%- endif -%}
{%- endfor %}
</ul>

{% for t in site.data.taxonomy.topics -%}
{%- assign topic_posts = site.posts | where_exp: "p", "p.categories contains t[0]" -%}
{%- if topic_posts.size > 0 -%}
<section class="taxonomy-section" id="{{ t[0] }}">
  <h2>{{ t[1].name | escape }}</h2>
  <p class="taxonomy-description">{{ t[1].description | escape }}</p>
  {% include post-list-compact.html posts=topic_posts %}
</section>
{% endif -%}
{%- endfor %}
