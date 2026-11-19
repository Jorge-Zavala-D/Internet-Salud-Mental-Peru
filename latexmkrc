# Both root documents use the same Zotero export. BibTeX requires a
# space-free database name in the .aux file, so add its directory here.
use Config;
$ENV{'BIBINPUTS'} = join($Config{path_sep}, './3 Paper', $ENV{'BIBINPUTS'} // '');
# Load the repository-local Beamer theme by its declared package name.
$ENV{'TEXINPUTS'} = join($Config{path_sep}, './4 Presentations/template', $ENV{'TEXINPUTS'} // '');
