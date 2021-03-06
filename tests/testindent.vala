/**
 * Test the indentation API.
 */

using Vanubi;

void assert_indent (Indent indenter, Buffer buffer, int line, int indent) {
	var iter = buffer.line_start (line);
	indenter.indent (iter);
	var res = buffer.get_indent (line) == indent;
	if (!res) {
		message("Got indent %d instead of %d for line %d", buffer.get_indent (line), indent, line);
		assert (buffer.get_indent (line) == indent);
	}
}

void assert_indent_c (Buffer buffer, int line, int indent) {
	var indenter = new Indent_C (buffer);
	assert_indent (indenter, buffer, line, indent);
}

void assert_indent_asm (Buffer buffer, int line, int indent) {
	var indenter = new Indent_Asm (buffer);
	assert_indent (indenter, buffer, line, indent);
}

void assert_indent_shell (Buffer buffer, int line, int indent) {
	var indenter = new Indent_C (buffer);
	assert_indent (indenter, buffer, line, indent);
}

void assert_indent_haskell (Buffer buffer, int line, int indent) {
	var indenter = new Indent_Haskell (buffer);
	assert_indent (indenter, buffer, line, indent);
}

void test_lang_c () {
	var buffer = new StringBuffer.from_text ("
foo {
    bar (foo
         baz);
} test;

single ')' {
inner ')';
next
}

multi (param1,
param2) {
body1
body2
}

try {
{
foo;
}
} catch {
inside
}

double (
close(
));

switch(foo) {
case bar:
test
break;
default:
break;
}

if {
if {
} else {
}
}

toplevel
");
	var w = buffer.tab_width;
	assert_indent_c (buffer, 0, 0);
	assert_indent_c (buffer, 1, 0);
	assert_indent_c (buffer, 2, w);
	assert_indent_c (buffer, 3, w*2+1);
	assert_indent_c (buffer, 4, 0);
	
	assert_indent_c (buffer, 6, 0);
	assert_indent_c (buffer, 7, w);
	assert_indent_c (buffer, 8, w);
	assert_indent_c (buffer, 9, 0);
	
	assert_indent_c (buffer, 11, 0);
	assert_indent_c (buffer, 12, 7);
	assert_indent_c (buffer, 13, w);
	assert_indent_c (buffer, 14, w);
	assert_indent_c (buffer, 15, 0);
	
	assert_indent_c (buffer, 17, 0);
	assert_indent_c (buffer, 18, w);
	assert_indent_c (buffer, 19, w*2);
	assert_indent_c (buffer, 20, w);
	assert_indent_c (buffer, 21, 0);
	assert_indent_c (buffer, 22, w);
	assert_indent_c (buffer, 23, 0);
	
	assert_indent_c (buffer, 25, 0);
	assert_indent_c (buffer, 26, w);
	assert_indent_c (buffer, 27, 0);
	
	assert_indent_c (buffer, 29, 0);
	assert_indent_c (buffer, 30, 0);
	assert_indent_c (buffer, 31, w);
	assert_indent_c (buffer, 32, w);
	assert_indent_c (buffer, 33, 0);
	assert_indent_c (buffer, 34, w);
	assert_indent_c (buffer, 35, 0);		
	
	assert_indent_c (buffer, 37, 0);
	assert_indent_c (buffer, 38, w);
	assert_indent_c (buffer, 39, w);
	assert_indent_c (buffer, 40, w);
	assert_indent_c (buffer, 41, 0);
}

void test_lang_asm () {
	var buffer = new StringBuffer.from_text ("
section .text
label1:
mov eax, ebx
xor eax, eax
label2:
enter
ret
");
	var w = buffer.tab_width;
	assert_indent_asm (buffer, 0, w);
	assert_indent_asm (buffer, 1, w);
	assert_indent_asm (buffer, 2, 0);
	assert_indent_asm (buffer, 3, w);
	assert_indent_asm (buffer, 4, w);
	assert_indent_asm (buffer, 5, 0);
	assert_indent_asm (buffer, 6, w);
	assert_indent_asm (buffer, 7, w);
}

void test_lang_shell () {
	var buffer = new StringBuffer.from_text ("
if foo; then
bar
else
baz
fi
");
	var w = buffer.tab_width;
	assert_indent_shell (buffer, 0, 0);
	assert_indent_shell (buffer, 1, 0);
	assert_indent_shell (buffer, 2, w);
	assert_indent_shell (buffer, 3, 0);
	assert_indent_shell (buffer, 4, w);
	assert_indent_shell (buffer, 5, 0);
}

void test_lang_haskell () {
	var buffer = new StringBuffer.from_text ("
main = do
foo =
case x of
bar -> baz
let
a = qux
b = hax

main = do
let a = b
c = d

data Foo = Foo
deriving (Show)
");

	var w = buffer.tab_width;
	assert_indent_haskell (buffer, 0, 0);
	assert_indent_haskell (buffer, 1, 0); // main = do
	assert_indent_haskell (buffer, 2, w); // foo =
	assert_indent_haskell (buffer, 3, w*2); // case x of
	assert_indent_haskell (buffer, 4, w*3); // bar -> baz
	assert_indent_haskell (buffer, 5, w*3); // let
	assert_indent_haskell (buffer, 6, w*4); // a = qux
	assert_indent_haskell (buffer, 7, w*4); // hax
	
	assert_indent_haskell (buffer, 10, w); // let a = b
	assert_indent_haskell (buffer, 11, w+4); // c = d
	
	assert_indent_haskell (buffer, 14, w); // deriving (Show)
}

void test_spaces () {
	var buffer = new StringBuffer.from_text ("
foo {
    bar (foo
   \t\tbaz);
} test;

");
	buffer.indent_mode = IndentMode.SPACES;
	var w = buffer.tab_width;
	assert_indent_c (buffer, 0, 0);
	assert_indent_c (buffer, 1, 0);
	assert_indent_c (buffer, 2, w);
	assert_indent_c (buffer, 3, w*2+1);
	assert_indent_c (buffer, 4, 0);

	string line = buffer.line_text (3);
	// ensure there's no tab after reindent
	assert (line.index_of_char ('\t') < 0);
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/indent/lang_c", test_lang_c);
	Test.add_func ("/indent/lang_asm", test_lang_asm);
	Test.add_func ("/indent/lang_shell", test_lang_shell);
	Test.add_func ("/indent/lang_haskell", test_lang_haskell);
	Test.add_func ("/indent/spaces", test_spaces);

	return Test.run ();
}
