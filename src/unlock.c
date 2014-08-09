
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>

#include "crypttab.h"

static const int kPasswordSize = 8192;
static const char *kDevPath = "/dev";
static const char *kCrypttabPath = "/etc/crypttab";
static const char *kNoKeyFile = "none";

int runchild( const char *input, int inputSize, const char *path, char *const args[] )
{
	int childStdin[ 2 ] = { -1, -1 };
	pid_t childPid = -1;

	pipe( childStdin );

	childPid = fork();

	if( childPid == 0 ) { // We are the child
		close( 0 );
		close( childStdin[ 1 ] );

		dup2( childStdin[ 0 ], 0 ); // make stdin

		int rc = execv( path, args );
		exit( rc );
	} else {
		close( childStdin[ 0 ] );

		write( childStdin[ 1 ], input, inputSize );
		close( childStdin[ 1 ] );

		waitpid( childPid, NULL, 0 );
	}

	return 0;
}

int main( int argc, char ** argv )
{
	struct crypttab crypttab = crypttab_parse( kCrypttabPath );

	char password[ kPasswordSize ];
	int passwordSize = 0;
	// Can't use fgets as no guarantee that characters are printable, etc
	for( int chr = 0; chr < kPasswordSize && !feof( stdin ); ++chr ) {
		int rc = fgetc( stdin );
		if( rc == EOF )  {
			passwordSize = chr;
			break;
		} else {
			password[ chr ] = (unsigned char) rc;
		}
	}
	
	crypttab_lookupblkids( &crypttab );

	for( int entryIdx = 0; entryIdx < crypttab.size; ++entryIdx ) {
		struct crypttab_entry *entry = crypttab.entries + entryIdx;

		if( strcmp( entry->keyfile, kNoKeyFile ) != 0 ) {
			continue;
		}

		if( strncmp( kDevPath, entry->real_device, strlen( kDevPath ) ) != 0 ) {
			fprintf( stderr, "Warning: device '%s' not found\n", entry->device );
			continue;
		}

		// Right, now we have something to unlock
		char *path = "/sbin/cryptsetup";
		char *args[] = {
			path,
			"luksOpen",
			entry->real_device,
			entry->mapper,
			NULL
		};

		runchild( password, passwordSize, path, args );
	}

	crypttab_free( &crypttab );

	system( "pkill cryptroot-ask" );

	return 0;
}

	

	
