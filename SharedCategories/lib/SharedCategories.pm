package SharedCategories;

use strict;

my $plugin = undef;

sub replace_blog_id {
	my $type = shift;
	my @blog_ids = ref $_[0] ? @{ $_[0] } : ($_[0] ? @_ : ());

    my $blog_id_sets = $plugin->get_config_value(
        'shared_categories_blog_id_sets' . ($type eq 'folder' ? '_folder' : '')
    ) || [];

    require MT::Blog;
    my $template_ids = $plugin->get_config_value(
        'shared_categories_template_ids' . ($type eq 'folder' ? '_folder' : '')
    ) || [];
	if (scalar(@$template_ids)) {
		my @metas = MT::Blog->meta_pkg->search(
			{
				'type' => 'template_set',
				'vchar' => $template_ids,
			},
			{
				'fetchonly' => [ 'blog_id', 'vchar' ],
			}
		);
		foreach my $id (@$template_ids) {
			my @set = map({
				$_->vchar eq $id ? ($_->blog_id) : ();
			} @metas);
			if (@set) {
				push(@$blog_id_sets, \@set);
			}
		}
	}

	foreach my $set (@$blog_id_sets) {
		@blog_ids = map({
			my $id = $_;
			if (grep({ $id == $_ } @{ $set })) {
				@$set;
			}
			else {
				$id;
			}
		} @blog_ids);
	}

	@blog_ids ? \@blog_ids : 0;
}

my %save_plugin_data;
sub init_request {
	my ($cb, $app) = @_;
    $plugin = $cb->{plugin};


	require MT::Category;
	no warnings 'redefine';

	my $load = \&MT::Category::load;
	if ($app->param('__mode') eq 'save_entry') {
		*MT::Category::load = sub {
			my ($class, $args, $cond) = @_;

			if (ref $args) {
				my $type = $class->class_type;
				if (my $blog_id = &replace_blog_id($type, $args->{'blog_id'} || 0)) {
					$args->{'blog_id'} = $blog_id;
				}
			}

			if (wantarray) {
				MT::Object::load(@_);
			}
			else {
				my $obj = MT::Object::load(@_);
				$obj->blog_id($app->param('blog_id'));
				$obj;
			}
		};
	}
	else {
		*MT::Category::load = sub {
			my ($class, $args, $cond) = @_;

			if (ref $args) {
				my $type = $class->class_type;
				if (my $blog_id = &replace_blog_id($type, $args->{'blog_id'} || 0)) {
					$args->{'blog_id'} = $blog_id;
				}
			}

			MT::Object::load(@_);
		};
	}

	my $load_iter = \&MT::Category::load_iter;
	*MT::Category::load_iter = sub {
		my ($class, $args, $cond) = @_;

		if (ref $args) {
			my $type = $class->class_type;
			if (my $blog_id = &replace_blog_id($type, $args->{'blog_id'} || 0)) {
				$args->{'blog_id'} = $blog_id;
			}
		}

		MT::Object::load_iter(@_);
	};

	my $count = \&MT::Category::count;
	*MT::Category::count = sub {
		my ($class, $args, $cond) = @_;

		if (ref $args) {
			if (my $blog_id = &replace_blog_id($args->{'blog_id'} || 0)) {
				$args->{'blog_id'} = $blog_id;
			}
		}

		MT::Object::count(@_);
	};

	my $remove = \&MT::Category::remove;
	*MT::Category::remove = sub {
		my ($obj, $terms) = @_;
		my $type = $obj->class_type;
		my $blog_id = undef;

		if (ref $obj) {
			$blog_id = &replace_blog_id($type, $obj->blog_id || 0);
		} else {
			if (ref $terms eq 'HASH') {
				$blog_id = &replace_blog_id($type, $terms->{blog_id} || 0);
			}
		}

		return if $blog_id && scalar(@$blog_id) >= 2;

		$remove->(@_);
	};

	if ($plugin->get_config_value('shared_categories_cat_path_patch')) {
        require MT::Template::ContextHandlers;
        my $cat_path_to_category = \&MT::Template::Context::cat_path_to_category;
        *MT::Template::Context::cat_path_to_category = sub {
            if (! grep($_[2] eq $_, 'category', 'folder')) {
                $_[2] = ($_[2] eq 'entry' ? 'category' : 'folder');
            }
            $cat_path_to_category->(@_);
        };
    }


	return unless $app->can('param');


	my $blog_id = $app->param('blog_id') || 0;
	if (! $blog_id) {
		foreach my $k (
			'shared_categories_blog_id_sets',
			'shared_categories_template_ids',
			'shared_categories_blog_id_sets_folder',
			'shared_categories_template_ids_folder',
		) {
			$save_plugin_data{$k} = $plugin->get_config_value($k) || [];
		}
	}
}

sub pre_save_inner {
	my ($class, $cb, $obj, $original) = @_;
	my $type = $class->class_type;
	my $key =
		'shared_categories_fix_blog_id' . ($type eq 'folder' ? '_folder' : '');

	if ($plugin->get_config_value($key)) {
        if (my $related = &replace_blog_id($type, $obj->blog_id)) {
            if ($obj->parent) {
                my $parent = $class->load($obj->parent);
                $obj->blog_id($parent->blog_id);
            }
        }
    }

    1;
}

sub category_pre_save {
	require MT::Category;
	&pre_save_inner('MT::Category', @_);
}

sub folder_pre_save {
	require MT::Folder;
	&pre_save_inner('MT::Folder', @_);
}

sub source_list_inner {
	my ($class, $cb, $app, $tmpl) = @_;

    require JSON;
    my $blog_id = $app->param('blog_id') || 0;
    my @cats = $class->load({
        'blog_id' => $blog_id,
    });
	my $type = $class->class_type;
    my %objs = map({ $_->id, $_->blog_id } @cats);
    my $json = JSON::to_json(\%objs);
    my $script = <<__EOS__;
<script type="text/javascript">
(function() {
var arr = $json;
var elms = document.getElementsByTagName('a');
var i;
for (i = 0; i < elms.length; i++) {
    var a = elms[i];
    var m = a.href.match(/(__mode=view&_type=$type&blog_id=)(\\d+)(&id=)(\\d+)/);
    if (m) {
        a.href = a.href.replace(
            /(__mode=view&_type=$type&blog_id=)(\\d+)(&id=)(\\d+)/,
            m[1] + arr[m[4]] + m[3] + m[4]
        );
    }
}
})();
</script>
__EOS__

    $$tmpl =~ s#</mtapp:listing>#$&$script#i;

    1;
}

sub source_list_category {
	require MT::Category;
	&source_list_inner('MT::Category', @_);
}

sub source_list_folder {
	require MT::Folder;
	&source_list_inner('MT::Folder', @_);
}

sub _hdlr_if_by_blog_id {
    my ($ctx, $args, $cond) = @_;
    my $app = MT->instance;

	my $type = 'category';
	if ($ctx->this_tag =~ m/folders?$/i) {
		$type = 'folder';
	}
    
    my $blog_id = $args->{'blog_id'};
    if (! ref $blog_id) {
        $blog_id = [ $blog_id ];
    }
	my @blog_id = map({
		(my $id = $_) =~ s/\\?\$(\w+)/$ctx->var($1)/ge;
		$id;
	} @$blog_id);

    my $blog_id_sets = $plugin->get_config_value(
        'shared_categories_blog_id_sets' . ($type eq 'folder' ? '_folder' : '')
    ) || [];

    foreach my $set (@$blog_id_sets) {
        if (! @$set) {
            next;
        }
        my $shared = 1;
        foreach my $id (@blog_id) {
            $shared &&= scalar(grep($id == $_, @$set));
        }
        if ($shared) {
            return 1;
        }
    }

    return 0;
}

sub _hdlr_if_template_set {
    my ($ctx, $args, $cond) = @_;
    my $app = MT->instance;
    my $blog_id = $ctx->stash('blog_id') || $ctx->var('blog_id') || $app->param('blog_id') || 0;

	my $type = 'category';
	if ($ctx->this_tag =~ m/folders?$/i) {
		$type = 'folder';
	}

    require MT::Blog;
    my $blog = MT::Blog->load($blog_id) || MT::Blog->new;
    my $id = $blog->template_set;
    my $template_ids = $plugin->get_config_value(
        'shared_categories_template_ids' . ($type eq 'folder' ? '_folder' : '')
    ) || [];

    grep($id eq $_, @$template_ids);
}

sub _hdlr_template_set_label {
    my ($ctx, $args, $cond) = @_;
    my $app = MT->instance;
    my $blog_id = $ctx->stash('blog_id') || $ctx->var('blog_id') || $app->param('blog_id') || 0;
    require MT::Blog;
    my $blog = MT::Blog->load($blog_id) || MT::Blog->new;

    my $set = $app->registry('template_sets')->{$blog->template_set};

    $set ? (ref $set->{label} ? $set->{label}->() : $set->{label}) : '';
}

sub source_blog_config {
	my ($cb, $app, $str, $fname) = @_;
	my $blog_id = $app->param('blog_id');
	$$str =~ s/\$blog_id/$blog_id/g;
}

sub plugin_data_post_save {
	my ($cb, $obj, $original) = @_;
	my $app = MT->instance;

	if (! $app->can('param')) {
		return 1;
	}

	if (lc($app->param('plugin_sig')) ne $plugin->id) {
		return 1;
	}

	my $blog_id = $app->param('blog_id') || 0;
	if (! $blog_id) {
		foreach my $k (
			'shared_categories_blog_id_sets',
			'shared_categories_template_ids',
			'shared_categories_blog_id_sets_folder',
			'shared_categories_template_ids_folder',
		) {
			$plugin->set_config_value($k, $save_plugin_data{$k});
		}
		return 1;
	}

	my $inner = sub {
		my $type = shift;
		my $pf =  $type eq 'folder' ? '_folder' : '';

		my $blog_id_sets = $plugin->get_config_value(
			'shared_categories_blog_id_sets' . $pf,
		) || [];
		my $template_ids = $plugin->get_config_value(
			'shared_categories_template_ids' . $pf,
		) || [];

		require MT::Blog;
		my $blog = MT::Blog->load($blog_id) || MT::Blog->new;
		my $blog_set = $blog->template_set;
		if ($app->param('template_set' . $pf)) {
			if (! grep($blog_set eq $_, @$template_ids)) {
				push(@$template_ids, $blog_set);
			}
		}
		else {
			@$template_ids = grep($blog_set ne $_, @$template_ids);
		}


		if ($app->param('with_blog_id' . $pf)) {
			@$blog_id_sets = grep({
				my $set = $_;
				not scalar(grep({$blog_id == $_} @$set));
			} @$blog_id_sets);

			my @blog_ids = $app->param('sc_blog_id' . $pf);
			if (scalar(@blog_ids) >= 2) {
				push(@$blog_id_sets, \@blog_ids);

				my $old_blog_id_sets_length;
				do {
					$old_blog_id_sets_length = scalar(@$blog_id_sets);
					my @new_id_sets = ();

					MARGE_SET_LOOP:
					foreach my $set (@$blog_id_sets) {
						foreach my $nset (@new_id_sets) {
							foreach my $id (@$set) {
								if (grep($id == $_, @$nset)) {
									foreach my $i (@$set) {
										if (! grep($i == $_, @$nset)) {
											push(@$nset, $i);
										}
									}
									next MARGE_SET_LOOP;
								}
							}
						}

						push(@new_id_sets, [ @$set ]);
					}

					$blog_id_sets = \@new_id_sets;
				} until ($old_blog_id_sets_length == scalar(@$blog_id_sets));
			}
		}
		else {
			foreach my $set (@$blog_id_sets) {
				for (my $i = 0; $i < scalar(@$set); $i++) {
					if ($set->[$i] == $blog_id) {
						splice(@$set, $i, 1);
					}
				}
			}
		}

		$plugin->set_config_value(
			'shared_categories_blog_id_sets' . $pf, $blog_id_sets
		);
		$plugin->set_config_value(
			'shared_categories_template_ids' . $pf, $template_ids
		);
	};

	$inner->('category');
	$inner->('folder');
}

1;
