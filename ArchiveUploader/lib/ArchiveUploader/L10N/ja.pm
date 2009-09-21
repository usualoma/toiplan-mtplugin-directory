package ArchiveUploader::L10N::ja;

use strict;
use base 'ArchiveUploader::L10N::en_us';
use vars qw( %Lexicon );

%Lexicon = (
	'toi-planning' => 'ToI企画',

	'A plugin which help to upload asset and index-template.' => 'アイテムやインデックステンプレートをアップロードできるようにします。',
	'Upload Asset archive file.' => 'アイテム',
    'Upload Index-template archive file.' => 'インデックステンプレート',
	'Select File' => 'ファイルを選択',

	'Upload Succeeded.' => 'アップロードが完了しました。',

	'The file with the following extensions can be uploaded.' => '以下の拡張子のアーカイブファイルでアップロードできます。',
	"[_1] is not supported filetype." => '[_1] という拡張子はサポートされていません。',
	"[_1] has no files" => '[_1] にはファイルが含まれていません。',

	'ArchiveUpload \'[_1]\' uploaded by \'[_2]\'' => '\'[_2]\'が\'[_1]\'をアップロードしました。',

	'Sort Order' => '登録順序',
	'Created Time' => '作成日時',
	'File Name' => 'ファイル名',
);

1;
