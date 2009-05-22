package DataExchanger::L10N::ja;

use strict;
use base 'DataExchanger::L10N::en_us';
use vars qw( %Lexicon );

%Lexicon = (
	'toi-planning' => 'ToI企画',
	'Import' => 'インポート',
	'Export' => 'エクスポート',
	'Upload Succeeded.' => 'アップロードが完了しました。',

	'The file with the following formats can be uploaded.' => '以下のフォーマットでアップロードできます。',
	"[_1] is not supported filetype." => '[_1] という拡張子はサポートされていません。',

	"A plugin enable to import and export blog's data." => 'ブログのデータをインポートしたりエクスポートしたりできます。',
);

1;
