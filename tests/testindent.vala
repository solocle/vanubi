/**
 * Test the indentation API.
 */

using Vanubi;

unowned string text = "
foo (
	bar (
";

StringBuffer setup () {
	var buffer = new StringBuffer.from_text (text);
	return buffer;
}

void test_simple () {
	var buffer = setup ();
	assert (buffer.text == text);

	var iter = buffer.line_start (0);
	iter.forward_char ();
	assert (iter.line == 1);
	assert (iter.char == 'f');
	iter.forward_char ();
	assert (iter.char == 'o');
	assert (iter.line_offset == 1);
	assert (buffer.get_indent (1) == 0);
}

void test_insert_delete () {
	var buffer = setup ();
	// set indent to 8 (2 tabs)
	var iter = buffer.line_start (1);
	buffer.set_indent (1, 8);
	assert (!iter.valid);

	iter = buffer.line_start (1);
	assert (iter.char == '\t');
	iter.forward_char ();
	assert (iter.char == '\t');
	iter.forward_char ();
	assert (iter.char == 'f');
	assert (buffer.get_indent (1) == 8);

	// set indent to 4 (1 tab)
	buffer.set_indent (1, 4);
	assert (!iter.valid);

	iter = buffer.line_start (1);
	assert (iter.char == '\t');
	iter.forward_char ();
	assert (iter.char == 'f');
	assert (buffer.get_indent (1) == 4);

	// delete 0 chars
	iter = buffer.line_start (1);
	var iter2 = iter.copy ();
	buffer.delete (iter, iter2);
	assert (buffer.get_indent (1) == 4);
	assert (iter2.valid);

	// delete 1 char
	iter2.forward_char ();
	assert (iter2.line_offset == iter.line_offset+1);
	buffer.delete (iter, iter2);
	assert (buffer.get_indent (1) == 0);
	assert (iter.line_offset == iter2.line_offset);

	// insert
	buffer.insert (iter, "\t");
	assert (!iter2.valid);
	assert (iter.line_offset == 1);
	assert (buffer.get_indent (1) == 4);
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/indent/simple", test_simple);
	Test.add_func ("/indent/insert_delete", test_insert_delete);

	return Test.run ();
}
