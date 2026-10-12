"""Read root identification properties from concatenated flattened device trees."""
import struct

def summarize(payload):
    trees = []
    start = 0
    while start < len(payload):
        header = struct.unpack_from('>10I', payload, start)
        magic, total, structure, strings = header[:4]
        assert magic == 0xd00dfeed and start + total <= len(payload), 'Invalid FDT bounds'
        offset = start + structure
        depth = 0
        properties = {}
        while True:
            token, = struct.unpack_from('>I', payload, offset)
            offset += 4
            if token == 1:
                offset = payload.index(b'\0', offset) + 1
                offset = start + (offset - start + 3) // 4 * 4
                depth += 1
            elif token == 2:
                depth -= 1
            elif token == 3:
                length, name_offset = struct.unpack_from('>II', payload, offset)
                offset += 8
                name_start = start + strings + name_offset
                name = payload[name_start:payload.index(b'\0', name_start)].decode()
                value = payload[offset:offset+length]
                offset = start + (offset - start + length + 3) // 4 * 4
                if depth == 1 and name in ('model', 'compatible', 'qcom,msm-id', 'qcom,board-id'):
                    if name.startswith('qcom,'):
                        assert len(value) % 4 == 0
                        properties[name] = list(struct.unpack('>' + 'I' * (len(value) // 4), value))
                    else:
                        properties[name] = value.rstrip(b'\0').decode().split('\0')
            elif token == 4:
                continue
            elif token == 9:
                break
            else:
                raise AssertionError('Unknown FDT token: ' + str(token))
        properties['bytes'] = total
        trees.append(properties)
        start += total
    return trees

if __name__ == '__main__':
    import sys
    from pathlib import Path
    trees = summarize(Path(sys.argv[1]).read_bytes())
    ids = sorted({tree['qcom,msm-id'][i] for tree in trees if 'qcom,msm-id' in tree
                  for i in range(0, len(tree['qcom,msm-id']), 2)})
    print('Device trees:', len(trees), 'SoC IDs:', ids)
