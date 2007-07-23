//
// Test PMC_Context
//

#include <iostream.h>
#include "Context.h"

int
main(int argc, char* argv[])
{
    int		sts = 0;
    int		c;
    char	buf[MAXHOSTNAMELEN];

    pmProgname = basename(argv[0]);

    while ((c = getopt(argc, argv, "D:?")) != EOF) {
	switch (c) {
	case 'D':
	    sts = __pmParseDebug(optarg);
            if (sts < 0) {
		pmprintf("%s: unrecognized debug flag specification (%s)\n",
			 pmProgname, optarg);
                sts = 1;
            }
            else {
                pmDebug |= sts;
		sts = 0;
	    }
            break;
	case '?':
	default:
	    sts = 1;
	    break;
	}
    }

    if (sts) {
	pmprintf("Usage: %s\n", pmProgname);
	pmflush();
	exit(1);
        /*NOTREACHED*/
    }

    (void)gethostname(buf, MAXHOSTNAMELEN);
    buf[MAXHOSTNAMELEN-1] = '\0';

    fprintf(stderr, "*** Simple connection ***\n");
    PMC_Source* src1 = PMC_Source::getSource(PM_CONTEXT_ARCHIVE, 
			"oview-short",
			PMC_false);

    if (src1->status() < 0) {
	pmprintf("%s: Error: Unable to create context to \"oview-short\": %s\n",
		 pmProgname, pmErrStr(src1->status()));
	pmflush();
	sts = 1;
    }

    PMC_Context context1(src1);

    if (context1.hndl() < 0) {
	pmflush();
	sts = 1;
    }

    context1.dump(cout);

    uint_t descIndex;
    uint_t indomIndex;

    fprintf(stderr, "\n*** Cacheing of descriptors and indoms ***\n");
    PMC_Desc* desc;
    PMC_Indom* indom;

    sts = context1.lookupDesc("hinv.ncpu", descIndex, indomIndex);
    if (sts < 0) {
	pmprintf("%s: Error: hinv.ncpu: %s\n",
		 pmProgname, pmErrStr(sts));
	pmflush();
	sts = 1;
    }
    else {
	desc = &context1.desc(descIndex);
	if (desc->status() < 0) {
	    pmprintf("%s: Error: hinv.ncpu descriptor: %s\n",
		     pmProgname, pmErrStr(desc->status()));
	    pmflush();
	    sts = 1;
	}
	else if (indomIndex < UINT_MAX) {
	    pmprintf("%s: Error: hinv.ncpu indom is not NULL\n",
		     pmProgname);
	    pmflush();
	    sts = 1;
	}
    }

    sts = context1.lookupDesc("hinv.cputype", descIndex, indomIndex);
    if (sts < 0) {
	pmprintf("%s: Error: hinv.cputype: %s\n",
		 pmProgname, pmErrStr(sts));
	pmflush();
	sts = 1;
    }
    else {
	desc = &context1.desc(descIndex);
	indom = &context1.indom(indomIndex);
	if (desc->status() < 0) {
	    pmprintf("%s: Error: hinv.cputype descriptor: %s\n",
		     pmProgname, pmErrStr(desc->status()));
	    pmflush();
	    sts = 1;
	}
	else if (indom->status() < 0) {
	    pmprintf("%s: Error: hinv.cputype indom: %s\n",
		     pmProgname, pmErrStr(indom->status()));
	    pmflush();
	    sts = 1;
	}
    }

    PMC_Indom* indom2;

    sts = context1.lookupDesc("hinv.map.cpu", descIndex, indomIndex);
    if (sts < 0) {
	pmprintf("%s: Error: hinv.map.cpu: %s\n",
		 pmProgname, pmErrStr(sts));
	pmflush();
	sts = 1;
    }
    else {
	desc = &context1.desc(descIndex);
	indom2 = &context1.indom(indomIndex);

	if (desc->status() < 0) {
	    pmprintf("%s: Error: hinv.map.cpu descriptor: %s\n",
		     pmProgname, pmErrStr(desc->status()));
	    pmflush();
	    sts = 1;
	}
	else if (indom2->status() < 0) {
	    pmprintf("%s: Error: hinv.map.cpu indom: %s\n",
		     pmProgname, pmErrStr(indom2->status()));
	    pmflush();
	    sts = 1;
	}
	else if (indom != indom2) {
	    pmprintf("%s: Error: hinv.cputype and hinv.map.cpu indoms are not the same\n",
		     pmProgname);
	    pmflush();
	    sts = 1;
	}
    }

    sts = context1.lookupDesc("hinv.ncpu", descIndex, indomIndex);
    if (sts < 0) {
	pmprintf("%s: Error: hinv.ncpu: %s\n",
		 pmProgname, pmErrStr(sts));
	pmflush();
	sts = 1;
    }
    else {
	desc = &context1.desc(descIndex);

	if (desc->status() < 0) {
	    pmprintf("%s: Error: hinv.ncpu descriptor: %s\n",
		     pmProgname, pmErrStr(desc->status()));
	    pmflush();
	    sts = 1;
	}
	else if (indomIndex < UINT_MAX) {
	    pmprintf("%s: Error: hinv.ncpu indom is not NULL\n",
		     pmProgname);
	    pmflush();
	    sts = 1;
	}
    }

    context1.dump(cout);

    fprintf(stderr, "\n*** Bad Context ***\n");
    PMC_Source* src2 = PMC_Source::getSource(PM_CONTEXT_HOST, 
			"no-such-host");

    if (src2->status() >= 0) {
	pmprintf("%s: Error: Able to create context to \"oview-short\": %s\n",
		 pmProgname, pmErrStr(src1->status()));
	pmflush();
	sts = 1;
    }

    PMC_Context context2(src2);

    if (context2.hndl() >= 0) {
	pmprintf("%s: Error: Created a valid context to an invalid host\n",
		 pmProgname);
	sts = 1;
    }

    pmflush();

    context2.dump(cout);

    fprintf(stderr, "\n*** Exiting ***\n");
    
    pmflush();
    return sts;
}
