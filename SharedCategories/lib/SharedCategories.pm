package SharedCategories;

use strict;

my $plugin = undef;

sub replace_blog_id {
	my @blog_ids = ref $_[0] ? @{ $_[0] } : ($_[0] ? @_ : ());

    my $blog_id_sets = $plugin->get_config_value(
        'shared_categories_blog_id_sets'
    ) || [];

    require MT::Blog;
    my $template_ids = $plugin->get_config_value(
        'shared_categories_template_ids'
    ) || [];
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

sub init_request {
	my ($cb, $app) = @_;
    $plugin = $cb->{plugin};


	require MT::Category;

	my $load = *MT::Category::load;
	*MT::Category::load = sub {
		my ($class, $args, $cond) = @_;

		if (ref $args) {
			if (my $blog_id = &replace_blog_id($args->{'blog_id'} || 0)) {
				$args->{'blog_id'} = $blog_id;
			}
		}

		MT::Object::load(@_);
	};

	my $load_iter = *MT::Category::load_iter;
	*MT::Category::load_iter = sub {
		my ($class, $args, $cond) = @_;

		if (ref $args) {
			if (my $blog_id = &replace_blog_id($args->{'blog_id'} || 0)) {
				$args->{'blog_id'} = $blog_id;
			}
		}

		MT::Object::load_iter(@_);
	};
}

sub category_pre_save {
	my ($cb, $obj, $original) = @_;

	if ($plugin->get_config_value('shared_categories_fix_blog_id')) {
        if (my $related = &replace_blog_id($obj->blog_id)) {
            if ($obj->parent) {
                my $parent = MT::Category->load($obj->parent);
                $obj->blog_id($parent->blog_id);
            }
        }
    }

    1;
}

sub source_list_category {
	my ($cb, $app, $tmpl) = @_;

    require MT::Category;
    require JSON;
    my $blog_id = $app->param('blog_id') || 0;
    my @cats = MT::Category->load({
        'blog_id' => $blog_id,
    });
    my %objs = map({ $_->id, $_->blog_id } @cats);
    my $json = JSON::objToJson(\%objs);
    my $script = <<__EOS__;
<script type="text/javascript">
(function() {
var arr = $json;
var elms = document.getElementsByTagName('a');
var i;
for (i = 0; i < elms.length; i++) {
    var a = elms[i];
    var m = a.href.match(/(__mode=view&_type=category&blog_id=)(\\d+)(&id=)(\\d+)/);
    if (m) {
        a.href = a.href.replace(
            /(__mode=view&_type=category&blog_id=)(\\d+)(&id=)(\\d+)/,
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

sub _hdlr_if_by_blog_id {
    my ($ctx, $args, $cond) = @_;
    my $app = MT->instance;
    
    my $blog_id = $args->{'blog_id'};
    if (! ref $blog_id) {
        $blog_id = [ $blog_id ];
    }
	my @blog_id = map({
		(my $id = $_) =~ s/\\?\$(\w+)/$ctx->var($1)/ge;
		$id;
	} @$blog_id);

    my $blog_id_sets = $plugin->get_config_value(
        'shared_categories_blog_id_sets'
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

    require MT::Blog;
    my $blog = MT::Blog->load($blog_id) || MT::Blog->new;
    my $id = $blog->template_set;
    my $template_ids = $plugin->get_config_value(
        'shared_categories_template_ids'
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

my ($save_blog_id_sets, $save_template_ids);
sub plugin_data_pre_save {
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
		$save_blog_id_sets = $plugin->get_config_value(
			'shared_categories_blog_id_sets'
		) || [];
		$save_template_ids = $plugin->get_config_value(
			'shared_categories_template_ids'
		) || [];
	}

	return 1;
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
		$plugin->set_config_value(
			'shared_categories_blog_id_sets', $save_blog_id_sets
		);
		$plugin->set_config_value(
			'shared_categories_template_ids', $save_template_ids
		);
		return 1;
	}

	my $blog_id_sets = $plugin->get_config_value(
		'shared_categories_blog_id_sets'
	) || [];
	my $template_ids = $plugin->get_config_value(
		'shared_categories_template_ids'
	) || [];

	require MT::Blog;
	my $blog = MT::Blog->load($blog_id) || MT::Blog->new;
	my $blog_set = $blog->template_set;
	if ($app->param('template_set')) {
		if (! grep($blog_set eq $_, @$template_ids)) {
			push(@$template_ids, $blog_set);
		}
	}
	else {
		@$template_ids = grep($blog_set ne $_, @$template_ids);
	}


	if ($app->param('with_blog_id')) {
		@$blog_id_sets = grep({
			my $set = $_;
			not scalar(grep({$blog_id == $_} @$set));
		} @$blog_id_sets);

		my @blog_ids = $app->param('sc_blog_id');
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
		'shared_categories_blog_id_sets', $blog_id_sets
	);
	$plugin->set_config_value(
		'shared_categories_template_ids', $template_ids
	);
}

1;
