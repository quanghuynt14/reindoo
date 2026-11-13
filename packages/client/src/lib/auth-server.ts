import { createServerFn } from '@tanstack/react-start';
import { getRequestHeaders } from '@tanstack/react-start/server'
import { authClient } from '@/lib/auth-client';

export const getCurrentSession = createServerFn({method: 'GET'})
  .handler(async () => {
    const headers = getRequestHeaders();

    // Rien de ces en-têtes ne part au journal : ils portent le cookie de
    // session, et un jeton recopié dans les logs se promène ensuite partout où
    // les logs vont. Même chose pour la session elle-même — elle contient
    // l'adresse e-mail de la personne.
    //
    // Le root appelle ceci avant chaque page. Sans ce filet, une panne du
    // service d'auth ne déconnecte pas le visiteur : elle emporte la page
    // entière — y compris « / », qui n'a besoin d'aucune session pour se
    // montrer, et qui est justement celle qu'un inconnu ouvre en premier.
    try {
      const { data } = await authClient.getSession({
        fetchOptions: {
          headers,
        },
      });

      return data;
    } catch (error) {
      console.error('Failed to read the session:', error);

      return null;
    }
  });
