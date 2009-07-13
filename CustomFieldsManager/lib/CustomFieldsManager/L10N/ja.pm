package CustomFieldsManager::L10N::ja;

use strict;
use base 'CustomFieldsManager::L10N::en_us';
use vars qw( %Lexicon );

%Lexicon = (
	'toi-planning' => 'ToI企画',
	'Import' => 'インポート',
	'Export' => 'エクスポート',
	'Upload Succeeded.' => 'インポートが完了しました。',

	'The file with the following formats can be uploaded.' => '以下のフォーマットでアップロードできます。',
	"[_1] is not supported filetype." => '[_1] という拡張子はサポートされていません。',

	'A plugin management CustomFields by CSV.' => 'CSVファイルを使ってカスタムフィールドを管理します',

	'Encoding' => '文字コード',
	'Examples' => '記入例',

	'Duplicated basename(s):' => 'ベースネームが重複しています:',
	'Duplicated tag(s):' => 'タグが重複しています:',
);

1;
