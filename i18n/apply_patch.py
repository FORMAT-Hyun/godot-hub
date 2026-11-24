"""i18n/patches/*.json 의 새 번역을 각 언어 파일 끝에 붙인다: python i18n/apply_patch.py <패치 파일>
패치의 "_keys_from" 은 그 번역들이 keys.json의 몇 번째부터인지 (다시 실행해도 중복되지 않게)."""
import json, os, sys

here = os.path.dirname(os.path.abspath(__file__))
patch = json.load(open(sys.argv[1], encoding='utf-8'))
start = patch.pop('_keys_from')
keys = json.load(open(os.path.join(here, 'keys.json'), encoding='utf-8'))
for lang, vals in patch.items():
    if start + len(vals) > len(keys):
        sys.exit('%s: 번역이 키보다 많아요' % lang)
    path = os.path.join(here, lang + '.json')
    data = json.load(open(path, encoding='utf-8'))
    s = data['strings'][:start]
    s += [''] * (start - len(s)) + vals
    data['strings'] = s
    json.dump(data, open(path, 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=0)
print('적용한 언어', len(patch))
