---
layout: page
title: Archive
permalink: /archive/
---
{%- assign by_year = site.posts | group_by_exp: "p", "p.date | date: '%Y'" -%}
<p class="year-index">
{%- for y in by_year %}<a href="#y{{ y.name }}">{{ y.name }}</a>{% unless forloop.last %} · {% endunless %}{% endfor -%}
</p>

{% for y in by_year -%}
<section class="taxonomy-section" id="y{{ y.name }}">
  <h2>{{ y.name }}</h2>
  {% include post-list-compact.html posts=y.items %}
</section>
{% endfor %}
