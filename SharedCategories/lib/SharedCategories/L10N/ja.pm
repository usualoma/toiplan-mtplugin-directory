package SharedCategories::L10N::ja;

use strict;
use base 'SharedCategories::L10N::en_us';
use vars qw( %Lexicon );

%Lexicon = (
	'toi-planning' => 'ToI企画',

	'Category sharing' => 'ブログ間でカテゴリーを共有します',

	'Shared by blog' => 'ブログ単位で共有',
	'Shared by template-set' => 'テンプレートセットで共有',

	'Fix blog id' => 'ブログIDを親カテゴリーに合わせる',
    'Fix a bug for MTEntries' => 'MTEntries の category 指定時の不具合を修正する',
	'Settings for folders.' => 'フォルダの設定',
	'Settings for categories.' => 'カテゴリーの設定',
);

1;
