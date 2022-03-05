import itertools
def generate_possible_dictionary_strings(dict_tokens):
  possible_dict_token_lists = list(itertools.permutations(dict_tokens))
  possible_dicts = []
  for ordered_seq in possible_dict_token_lists:
    keys = [i for i in range(len(ordered_seq))]
    all_keys_permutations = list(itertools.permutations(keys))
    for key_set in all_keys_permutations:
      dict_str = "{"
      for i in key_set:
        dict_str += str(i) + ": " + ordered_seq[i] + ", "
      # Remove the last comma
      dict_str = dict_str[:-2]
      dict_str += "}"
      possible_dicts.append(dict_str)
  return possible_dicts


## Limitation: max dict size is 10 keys
def permute_string_dict(string_dict):
  if (string_dict == "{}"):
      return ["{}"]
  tokens = []
  for i in range(len(string_dict)-3):
    if (string_dict[i] >= '0' and string_dict[i] <= '9' and string_dict[i+1] == ':' and string_dict[i+2] == ' '):
      start = i+3
      end = i+3
      for j in range (i+3, len(string_dict)):
        if (string_dict[j] == '}'):
          end = j-1
          break
        elif (j < len(string_dict)-3 and string_dict[j] == ',' and string_dict[j+1] == ' ' and string_dict[j+2] >= '0' and string_dict[j+2] <= '9'):
          end = j-1
          break
      tokens.append(string_dict[start:end+1])
  return generate_possible_dictionary_strings(tokens)


# Limitation: we don't support nested maps
def get_metadata_possibilities(str):
  metadata_possibilities = []
  begin = 0
  end  = 0
  for i in range(len(str)):
    if (str[i] == '{'):
      begin = i
    if (str[i] == '}'):
      end = i
      possible_string_dicts = permute_string_dict(str[begin:end+1])
      for j in range(len(possible_string_dicts)):
        metadata_possibilities.append(str[0:begin] + possible_string_dicts[j] + str[end+1:len(str)])
  return metadata_possibilities

def result_equals_expected_metadata(result, expected_metadata):
    equivallent_metadata_possibilities = get_metadata_possibilities(expected_metadata)
    for p in equivallent_metadata_possibilities:
        if result == p:
            return True
    return False
