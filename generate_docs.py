from ruamel.yaml import YAML
import collections, re, requests
yaml = YAML(typ='safe')


hide_elements = {
    'background', 'background9', 'scroll_container', 'scrollbar', 'tabheader'
}
special_case_names = {'tablecolumns': 'TableColumns',
                      'tableoptions': 'TableOptions'}


def fetch_elements():
    res = requests.get('https://github.com/luk3yx/minetest-formspec_ast/raw/'
                       'master/elements.yaml')
    return yaml.load(res.text)


Field = collections.namedtuple('Field', 'name type is_list', defaults=(False,))


def search_for_fields(obj, *, is_list=False):
    assert isinstance(obj, (list, tuple))
    if len(obj) == 2:
        if obj[1] == '...':
            yield from search_for_fields(obj[0], is_list=True)
            return
        if isinstance(obj[0], str) and isinstance(obj[1], str):
            yield Field(obj[0], obj[1], is_list)
            return

    for e in obj:
        yield from search_for_fields(e)


def optional(element_name, field_name):
    if field_name in ('w', 'h'):
        return (element_name not in ('list', 'hypertext', 'model') and
                'image' not in element_name)
    return field_name == 'name'


def element_to_docs(element_name, variants):
    if element_name in special_case_names:
        flow_name = special_case_names[element_name]
    else:
        flow_name = re.sub(r'_(.)', lambda m: m.group(1).upper(),
                           element_name.capitalize())

    fields = collections.Counter(search_for_fields(variants))
    if ((element_name in hide_elements or Field('x', 'number') not in fields or
            all(field.name in ('x', 'y') for field in fields)) and
            element_name not in special_case_names):
        return ''

    lines = [
        f'### `gui.{flow_name}`\n',
        f"Equivalent to Minetest's `{element_name}[]` element.\n",
        '**Example**',
        '```lua',
        f'gui.{flow_name} {{'
    ]

    num = 1
    indent = ' ' * 4
    if element_name == 'tablecolumns':
        lines.append(f'{indent}tablecolumns = {{')
        lines.append(f'{indent}{indent}{{')
        indent += ' ' * 8

    for field, count in fields.items():
        if (field.name in ('x', 'y') or (element_name == 'tooltip' and
                                         field.name in ('w', 'h'))):
            continue

        if field.type == 'number':
            value = num
            num += 1
        elif field.type == 'string':
            if field.name == 'name':
                value = f'"my_{element_name}"'
            elif field.name == 'orientation':
                value = '"vertical"'
            elif 'color' in field.name:
                value = '"#FF0000"'
            elif field.name == 'type':
                value = '"text"'
            elif field.name == 'gui_element_name':
                value = '"my_button"'
            elif 'texture' in field.name:
                value = '"texture.png"'
            else:
                value = '"Hello world!"'
        elif field.type in ('boolean', 'fullscreen'):
            value = 'false'
        elif field.type == 'table':
            value = '{field = "value"}'
        else:
            value = '<?>'

        if field.is_list and field.type != 'table':
            value = f'{{{value}, ...}}'

        line = f'{indent}{field.name} = {value},'
        if ((count < len(variants) or optional(element_name, field.name)) and
                field.name != 'gui_element_name'):
            line = line + ' -- Optional'
        lines.append(line)

    if element_name == 'tablecolumns':
        lines.append(' ' * 8 + '},')
        lines.append(' ' * 8 + '...')
        lines.append(' ' * 4 + '}')

    lines.append('}')
    lines.append('```')

    return '\n'.join(lines)


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
