/* ;-*-C-*-; 
** Copyright (c) Massachusetts Institute of Technology 1994-1998.
**          All Rights Reserved.
**          Unpublished rights reserved under the copyright laws of
**          the United States.
**
** THIS MATERIAL IS PROVIDED AS IS, WITH ABSOLUTELY NO WARRANTY EXPRESSED
** OR IMPLIED.  ANY USE IS AT YOUR OWN RISK.
**
** This code is distributed freely and may be used freely under the 
** following conditions:
**
**     1. This notice may not be removed or altered.
**
**     2. Works derived from this code are not distributed for
**        commercial gain without explicit permission from MIT 
**        (for permission contact lclint-request@sds.lcs.mit.edu).
*/
/*
** cttable.i
**
** NOTE: This is not a stand-alone source file, but is included in ctype.c.
**       (This is necessary becuase there is no other way in C to have a
**       hidden scope, besides at the file level.)
*/

/*@access ctype@*/
           
/*
** type definitions and forward declarations in ctbase.i
*/

static void
ctentry_free (/*@only@*/ ctentry c)
{
  ctbase_free (c->ctbase);
  cstring_free (c->unparse);
  sfree (c);
}

static void cttable_reset (void)
   /*@globals cttab@*/
   /*@modifies cttab@*/
{
  if (cttab.entries != NULL) 
    {
      int i;  

      for (i = 0; i < cttab.size; i++)
	{
	  ctentry_free (cttab.entries[i]);
	}
      
      /*@-compdestroy@*/ 
      sfree (cttab.entries);
      /*@=compdestroy@*/

      cttab.entries = NULL;
    }

  cttab.size = 0 ;
  cttab.nspace = 0 ;
}

static /*@observer@*/ ctbase ctype_getCtbase (ctype c)
{
  /*@+enumint@*/
  if (c >= 0 && c < cttab.size)
    {
      return (cttab.entries[c]->ctbase);
    }
  else 
    {
      if (c == CTK_UNKNOWN)
	llbuglit ("ctype_getCtbase: ctype unknown");
      if (c == CTK_INVALID)
	llbuglit ("ctype_getCtbase: ctype invalid");
      if (c == CTK_DNE)
	llbuglit ("ctype_getCtbase: ctype dne");
      if (c == CTK_ELIPS)
	llbuglit ("ctype_getCtbase: elips marker");
      
      llfatalbug (message ("ctype_getCtbase: ctype out of range: %d", c));
      BADEXIT;
    }

  /*@=enumint@*/
}

static /*@notnull@*/ /*@observer@*/ ctbase
ctype_getCtbaseSafe (ctype c)
{
  ctbase res = ctype_getCtbase (c);

  llassert (ctbase_isDefined (res));
  return res;
}

/*
** ctentry
*/

static ctentry
ctype_getCtentry (ctype c)
{
  static /*@only@*/ ctentry errorEntry = NULL;

  if (cttab.size == 0)
    {
      if (errorEntry == NULL)
	{
	  errorEntry = ctentry_makeNew (CTK_UNKNOWN, ctbase_undefined);
	}

      return errorEntry;
    }

  /*@+enumint@*/
  if (c >= CTK_PLAIN && c < cttab.size)
    {
      return (cttab.entries[c]);
    }
  else if (c == CTK_UNKNOWN) 
    llcontbuglit ("ctype_getCtentry: ctype unknown");
  else if (c == CTK_INVALID)
    llcontbuglit ("ctype_getCtentry: ctype invalid (ctype_undefined)");
  else if (c == CTK_DNE)
    llcontbuglit ("ctype_getCtentry: ctype dne");
  else if (c == CTK_ELIPS) 
    llcontbuglit ("ctype_getCtentry: ctype elipsis");
  else if (c == CTK_MISSINGPARAMS) 
    llcontbuglit ("ctype_getCtentry: ctype missing params");
  else
    llbug (message ("ctype_getCtentry: ctype out of range: %d", c));

  return (cttab.entries[ctype_unknown]);
  /*@=enumint@*/
}

static ctentry
ctentry_makeNew (ctkind ctk, /*@only@*/ ctbase c)
{
  
  return (ctentry_make (ctk, c, ctype_dne, ctype_dne, ctype_dne, cstring_undefined));
}

static /*@only@*/ ctentry
ctentry_make (ctkind ctk,
	      /*@keep@*/ ctbase c, ctype base,
	      ctype ptr, ctype array,
	      /*@keep@*/ cstring unparse) /*@*/ 
{
  ctentry cte = (ctentry) dmalloc (sizeof (*cte));
  cte->kind = ctk;
  cte->ctbase = c;
  cte->base = base;
  cte->ptr = ptr;
  cte->array = array;
  cte->unparse = unparse;
  return cte;
}

static cstring
ctentry_unparse (ctentry c)
{
  return (message 
	  ("%20s [%d] [%d] [%d]",
	   (cstring_isDefined (c->unparse) ? c->unparse : cstring_makeLiteral ("<no name>")),
	   c->base, 
	   c->ptr,
	   c->array));
}

static bool
ctentry_isInteresting (ctentry c)
{
  return (cstring_isNonEmpty (c->unparse));
}

static /*@only@*/ cstring
ctentry_dump (ctentry c)
{
  DPRINTF (("Dumping: %s", ctentry_unparse (c)));

  if (c->ptr == ctype_dne
      && c->array == ctype_dne
      && c->base == ctype_dne)
    {
      return (message ("%d %q&", 
		       ctkind_toInt (c->kind),
		       ctbase_dump (c->ctbase)));
    }
  else if (c->base == ctype_undefined
	   && c->array == ctype_dne)
    {
      if (c->ptr == ctype_dne)
	{
	  return (message ("%d %q!", 
			   ctkind_toInt (c->kind),
			   ctbase_dump (c->ctbase)));
	}
      else
	{
	  return (message ("%d %q^%d", 
			   ctkind_toInt (c->kind),
			   ctbase_dump (c->ctbase),
			   c->ptr));
	}
    }
  else if (c->ptr == ctype_dne
	   && c->array == ctype_dne)
    {
      return (message ("%d %q%d&", 
		       ctkind_toInt (c->kind),
		       ctbase_dump (c->ctbase),
		       c->base));
    }
  else
    {
      return (message ("%d %q%d %d %d", 
		       ctkind_toInt (c->kind),
		       ctbase_dump (c->ctbase),
		       c->base, c->ptr, c->array));
    }
}


static /*@only@*/ ctentry
ctentry_undump (/*@dependent@*/ char *s)
{
  int base, ptr, array;
  ctkind kind;
  ctbase ct;

  kind = ctkind_fromInt (getInt (&s));
  ct = ctbase_undump (&s);

  if (optCheckChar (&s, '&'))
    {
      base = ctype_dne;
      ptr = ctype_dne;
      array = ctype_dne;
    }
  else if (optCheckChar (&s, '!'))
    {
      base = ctype_undefined;
      ptr = ctype_dne;
      array = ctype_dne;
    }
  else if (optCheckChar (&s, '^'))
    {
      base = ctype_undefined;
      ptr = getInt (&s);
      array = ctype_dne;
    }
  else
    {
      base = getInt (&s);
      
      if (optCheckChar (&s, '&'))
	{
	  ptr = ctype_dne;
	  array = ctype_dne;
	}
      else
	{
	  ptr = getInt (&s);
	  array = getInt (&s);
	}
    }

  /* can't unparse w/o typeTable */
  return (ctentry_make (kind, ct, base, ptr, array, cstring_undefined));
}

static /*@observer@*/ cstring
ctentry_doUnparse (ctentry c) /*@modifies c@*/
{
  if (cstring_isDefined (c->unparse))
    {
      return (c->unparse);
    }
  else
    {
      cstring s = ctbase_unparse (c->ctbase);

      if (!cstring_isEmpty (s) && !cstring_containsChar (s, '<'))
	{
	  c->unparse = s;
	}
      else
	{
	  cstring_markOwned (s);
	}

      return (s);
    }
}

static /*@observer@*/ cstring
ctentry_doUnparseDeep (ctentry c)
{
  if (cstring_isDefined (c->unparse))
    {
      return (c->unparse);
    }
  else
    {
      c->unparse = ctbase_unparseDeep (c->ctbase);
      return (c->unparse);
    }
}

/*
** cttable operations
*/

static /*@only@*/ cstring
cttable_unparse (void)
{
  int i;
  cstring s = cstring_undefined;

  /*@access ctbase@*/
  for (i = 0; i < cttab.size; i++)
    {
      ctentry cte = cttab.entries[i];
      if (ctentry_isInteresting (cte))
	{
	  if (ctbase_isUA (cte->ctbase))
	    {
	      s = message ("%s%d\t%q [%d]\n", s, i, ctentry_unparse (cttab.entries[i]),
			   cte->ctbase->contents.tid);
	    }
	  else
	    {
	      s = message ("%s%d\t%q\n", s, i, ctentry_unparse (cttab.entries[i]));
	    }
	}
    }
  /*@noaccess ctbase@*/
  return (s);
}

void
cttable_print (void)
{
  int i;

  /*@access ctbase@*/
  for (i = 0; i < cttab.size; i++)
    {
      ctentry cte = cttab.entries[i];

      if (ctentry_isInteresting (cte))
	{
	  if (ctbase_isUA (cte->ctbase))
	    {
	      fprintf (g_msgstream, "%3d: %s [%d]\n", i, 
		       cstring_toCharsSafe (ctentry_doUnparse (cttab.entries[i])),
		       cte->ctbase->contents.tid);
	    }
	  else
	    {
	      fprintf (g_msgstream, "%3d: %s\n", i, 
		       cstring_toCharsSafe (ctentry_doUnparse (cttab.entries[i])));
	    }
	}
      else
	{
	  /* fprintf (g_msgstream, "%3d: <no name>\n", i); */
	}
    }
  /*@noaccess ctbase@*/
}

/*
** cttable_dump
**
** Output cttable for dump file
*/

static void
cttable_dump (FILE *fout)
{
  bool showdots = FALSE;
  int showdotstride = 0;
  int i;
  
  if (context_getFlag (FLG_SHOWSCAN) && cttab.size > 5000)
    {
      fprintf (g_msgstream, " >\n"); /* end dumping to */
      fprintf (g_msgstream, "< Dumping type table (%d types) ", cttab.size);
      showdotstride = cttab.size / 5;
      showdots = TRUE;
    }

  for (i = 0; i < cttab.size; i++)
    {
      cstring s;

      s = ctentry_dump (cttab.entries[i]);
      llassert (cstring_length (s) < MAX_DUMP_LINE_LENGTH);
      fputline (fout, cstring_toCharsSafe (s));
      cstring_free (s);

      if (showdots && (i != 0 && ((i - 1) % showdotstride == 0)))
	{
	  (void) fflush (g_msgstream);
	  fprintf (stderr, ".");
	  (void) fflush (stderr);
	}
    }

  if (showdots)
    {
      fprintf (stderr, " >\n< Continuing dump ");
    }
  
}

/*
** load cttable from init file
*/

static void cttable_load (FILE *f) 
  /*@globals cttab @*/
  /*@modifies cttab, f @*/
{
  char *s = mstring_create (MAX_DUMP_LINE_LENGTH);
  ctentry cte;

  cttable_reset ();

  while (fgets (s, MAX_DUMP_LINE_LENGTH, f) != NULL && *s == ';')
    {
      ;
    }
  
  if (mstring_length (s) == (MAX_DUMP_LINE_LENGTH - 1))
    {
      llbug (message ("Library line too long: %s\n", cstring_fromChars (s)));
    }
  
  while (s != NULL && *s != ';' && *s != '\0')
    {
      ctype ct;

      cte = ctentry_undump (s);
      ct = cttable_addFull (cte);

      if (ctbase_isConj (cte->ctbase)
	  && !(cte->ctbase->contents.conj->isExplicit))
	{
	  ctype_recordConj (ct);
	}

      (void) fgets (s, MAX_DUMP_LINE_LENGTH, f);
    }

  sfree (s);
  }

/*
** cttable_init
**
** fill up the cttable with basic types, and first order derivations.
** this is done without using our constructors for efficiency reasons
** (probably bogus)
**
*/

/*@access cprim@*/
static void cttable_init (void) 
   /*@globals cttab@*/ /*@modifies cttab@*/
{
  ctkind i;
  cprim  j;
  ctbase ct = ctbase_undefined; 

  llassert (cttab.size == 0);

  /* do for plain, pointer, arrayof */
  for (i = CTK_PLAIN; i <= CTK_ARRAY; i++)	
    {
      for (j = CTX_UNKNOWN; j <= CTX_LAST; j++)
	{
	  if (i == CTK_PLAIN)
	    {
	      if (j == CTX_BOOL)
		{
		  ct = ctbase_createBool (); /* why different? */
		}
	      else if (j == CTX_UNKNOWN)
		{
		  ct = ctbase_createUnknown ();
		}
	      else
		{
		  ct = ctbase_createPrim ((cprim)j);
		}

	      (void) cttable_addFull 
		(ctentry_make (CTK_PLAIN,
			       ct, ctype_undefined, 
			       j + CTK_PREDEFINED, j + CTK_PREDEFINED2,
			       ctbase_unparse (ct)));
	    }
	  else
	    {
	      switch (i)
		{
		case CTK_PTR:
		  ct = ctbase_makePointer (j);
		  /*@switchbreak@*/ break;
		case CTK_ARRAY:
		  ct = ctbase_makeArray (j);
		  /*@switchbreak@*/ break;
		default:
		  llbugexitlit ("cttable_init: base case");
		}
	      
	      (void) cttable_addDerived (i, ct, j);
	    }
	}
    }

  /**** reserve a slot for userBool ****/
  (void) cttable_addFull (ctentry_make (CTK_INVALID, ctbase_undefined, 
					ctype_undefined, ctype_dne, ctype_dne, 
					cstring_undefined));
}

/*@noaccess cprim@*/

static void
cttable_grow ()
{
  int i;
  o_ctentry *newentries ;

  cttab.nspace = CTK_BASESIZE;
  newentries = (ctentry *) dmalloc (sizeof (*newentries) * (cttab.size + cttab.nspace));

  if (newentries == NULL)
    {
      llfatalerror (message ("cttable_grow: out of memory.  Size: %d", 
			     cttab.size));
    }

  for (i = 0; i < cttab.size; i++)
    {
      newentries[i] = cttab.entries[i];
    }

  /*@-compdestroy@*/
  sfree (cttab.entries);
  /*@=compdestroy@*/

  cttab.entries = newentries;
/*@-compdef@*/
} /*@=compdef@*/

static ctype
cttable_addDerived (ctkind ctk, /*@keep@*/ ctbase cnew, ctype base)
{
  if (cttab.nspace == 0)
    cttable_grow ();
  
  cttab.entries[cttab.size] = 
    ctentry_make (ctk, cnew, base, ctype_dne, ctype_dne, cstring_undefined);

  cttab.nspace--;
  
  return (cttab.size++);
}

static ctype
cttable_addComplex (/*@only@*/ /*@notnull@*/ ctbase cnew)
   /*@modifies cttab; @*/
{
  if (cnew->type != CT_FCN && cnew->type != CT_EXPFCN) 
    {
      ctype i;
      int ctstop = cttable_lastIndex () - DEFAULT_OPTLEVEL;
      
      if (ctstop < LAST_PREDEFINED)
	{
	  ctstop = LAST_PREDEFINED;
	}

      for (i = cttable_lastIndex (); i >= ctstop; i--)	/* better to go from back... */
	{
	  ctbase ctb;
	  
	  ctb = ctype_getCtbase (i);

	  if (ctbase_isDefined (ctb) && ctbase_equivStrict (cnew, ctb))
	    {
	      DPRINTF (("EQUIV!! %s / %s",
			ctbase_unparse (cnew),
			ctbase_unparse (ctb)));
	      ctbase_free (cnew);
	      return i;
	    }
	}
    }
  
  if (cttab.nspace == 0)
    cttable_grow ();
  
  cttab.entries[cttab.size] = ctentry_make (CTK_COMPLEX, cnew, ctype_undefined, 
					    ctype_dne, ctype_dne,
					    cstring_undefined);
  cttab.nspace--;
  
  return (cttab.size++);
}

static ctype
cttable_addFull (ctentry cnew)
{
  if (cttab.nspace == 0)
    {
      cttable_grow ();
    }

  cttab.entries[cttab.size] = cnew;
  cttab.nspace--;

  return (cttab.size++);
}

static ctype
cttable_addFullSafe (/*@only@*/ ctentry cnew)
{
  int i;
  ctbase cnewbase = cnew->ctbase;

  llassert (ctbase_isDefined (cnewbase));

  for (i = cttable_lastIndex (); i >= CT_FIRST; i--)
    {
      ctbase ctb = ctype_getCtbase (i);

      if (ctbase_isDefined (ctb) 
	  && ctbase_equiv (cnewbase, ctype_getCtbaseSafe (i)))
	{
	  ctentry_free (cnew);
	  return i;
	}
    }

  if (cttab.nspace == 0)
    cttable_grow ();

  cttab.entries[cttab.size] = cnew;

  cttab.nspace--;
  
  return (cttab.size++);
}

