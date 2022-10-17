from ruamel.yaml import YAML
import collections, re, requests
yaml = YAML(typ='safe')


def fetch_elements():
    res = requests.get('https://github.com/luk3yx/minetest-formspec_ast/raw/'
                       'master/elements.yaml')
    return yaml.load(res.text)


def search_for_fields(obj):
    assert isinstance(obj, (list, tuple))
    if len(obj) == 2:
        if obj[1] == '...':
            yield from search_for_fields(obj[0])
            return
        if isinstance(obj[0], str) and isinstance(obj[1], str):
            yield tuple(obj)
            return

    for e in obj:
        yield from search_for_fields(e)


def element_to_docs(element_name, variants):
    flow_name = re.sub(r'_(.)', lambda m: m.group(1).upper(),
                       element_name.capitalize())

    res = [
        f'### `gui.{flow_name}`\n',
        f"Equivalent to Minetest's `{element_name}[]` element.\n",
        '**Example**',
        '```lua',
        f'gui.{flow_name} {{'
    ]

    fields = collections.Counter(search_for_fields(variants))
    if (('x', 'number') not in fields or
            all(field_name in ('x', 'y') for field_name, _ in fields)):
        return ''

    num = 1

    for (field_name, field_type), count in fields.items():
        if field_name in ('x', 'y'):
            continue

        if field_type == 'number':
            value = num
            num += 1
        elif field_type == 'string':
            if field_name == 'name':
                value = f'"my_{element_name}"'
            elif field_name == 'orientation':
                value = '"vertical"'
            elif 'color' in field_name:
                value = '"#FF0000"'
            else:
                value = '"Hello world!"'
        elif field_type in ('boolean', 'fullscreen'):
            value = 'false'
        elif field_type == 'table':
            value = '{field = "value"}'
        else:
            value = '<?>'

        line = f'    {field_name} = {value},'
        if ((field_name in ('name', 'w', 'h') and element_name != 'list') or
                count < len(variants)):
            line = line + ' -- Optional'
        res.append(line)

    res.append('}')
    res.append('```')

    return '\n'.join(res)


if __name__ == '__main__':
    print('Fetching data...')
    elements = fetch_elements()
    print('Done.')

    with open('elements.md', 'w') as f:
        f.write('# Auto-generated elements list\n\n')
        f.write('This is probably broken.')
        for element_name, variants in elements.items():
            docs = element_to_docs(element_name, variants)
            if docs:
                f.write('\n\n')
                f.write(docs)
