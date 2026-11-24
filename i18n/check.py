"""번역 파일 검사 · 정리: python i18n/check.py
- 각 <언어>.json 의 문자열 개수가 keys.json 과 같은지
- %s · %d · %% 자리 개수가 원문과 같은지 (다르면 그 줄은 비워서 원문/영어로 떨어지게 함)
- 원문 앞뒤의 공백 · 줄바꿈을 번역에도 똑같이 붙여 줌 (문자열을 이어 붙이는 곳이 있어서)
"""
import json, os, re, sys

here = os.path.dirname(os.path.abspath(__file__))
keys = json.load(open(os.path.join(here, 'keys.json'), encoding='utf-8'))
ph = re.compile(r'%[sd%]')
bad_total = 0


def edges(s):
    m = re.match(r'^(\s*)(.*?)(\s*)$', s, re.S)
    return m.group(1), m.group(2), m.group(3)


for name in sorted(os.listdir(here)):
    if not name.endswith('.json') or name == 'keys.json':
        continue
    path = os.path.join(here, name)
    data = json.load(open(path, encoding='utf-8'))
    vals = data['strings']
    problems = []
    if len(vals) != len(keys):
        problems.append('개수 %d (원문 %d)' % (len(vals), len(keys)))
    fixed = []
    for i, k in enumerate(keys):
        v = vals[i] if i < len(vals) else ''
        if v and sorted(ph.findall(v)) != sorted(ph.findall(k)):
            problems.append('#%d 자리 표시 다름: %r' % (i, v))
            v = ''
        if v:
            lead, _, trail = edges(k)
            v = lead + edges(v)[1] + trail
        fixed.append(v)
    data['strings'] = fixed
    json.dump(data, open(path, 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=0)
    bad_total += len(problems)
    print('%-12s %s' % (name, 'OK' if not problems else '; '.join(problems[:5])))
sys.exit(1 if bad_total else 0)
