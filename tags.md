---
layout: page
title: Tags
permalink: /tags/
---
{%- comment -%} Iterating a hash yields [key, value] pairs; collect the keys. {%- endcomment -%}
{%- assign tag_keys = "" | split: "" -%}
{%- for pair in site.data.taxonomy.tags -%}{%- assign tag_keys = tag_keys | push: pair[0] -%}{%- endfor -%}
{%- assign tag_keys = tag_keys | sort_natural -%}
<p class="tag-cloud">
{%- for key in tag_keys -%}
  {%- assign tagged = site.posts | where_exp: "p", "p.tags contains key" -%}
  {%- if tagged.size > 0 %}
  <a href="#{{ key }}" class="post-tag">#{{ site.data.taxonomy.tags[key].name | escape }} <span class="count">{{ tagged.size }}</span></a>
  {%- endif -%}
{%- endfor %}
</p>

{% for key in tag_keys -%}
{%- assign tagged = site.posts | where_exp: "p", "p.tags contains key" -%}
{%- if tagged.size > 0 -%}
<section class="taxonomy-section" id="{{ key }}">
  <h2>#{{ site.data.taxonomy.tags[key].name | escape }}</h2>
  {% include post-list-compact.html posts=tagged %}
</section>
{% endif -%}
{%- endfor %}
